#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include <DHT.h>
#include <esp_wifi.h>
#include <esp_system.h>
#include <cstring>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "device_config.h"
#include "firebase_secrets.h"
#include "light_sensor.h"
#include "telemetry_schedule.h"
#include "task_watchdog.h"
#include "wifi_scan_api.h"
#include "portal_ui.h"

// ESP32 Dev Module + DHT22 on GPIO 4 + analog LDR on GPIO 34.
// All Flutter endpoints are registered here, including asynchronous Wi-Fi scans.
// No sensor values are invented and Wi-Fi passwords are never printed.

WebServer server(80);
DNSServer dnsServer;
DHT dht(DHT_DATA_PIN, DHT22);
FirebaseData firebaseData;
FirebaseAuth firebaseAuth;
FirebaseConfig firebaseConfig;
QueueHandle_t telemetryQueues[TELEMETRY_METRIC_COUNT] = {};
EventGroupHandle_t telemetryConnection = nullptr;
constexpr EventBits_t TELEMETRY_CONNECTED = BIT0;
TelemetrySchedule dhtSchedule(SENSOR_UPLOAD_INTERVAL_MS, DHT_MINIMUM_READ_INTERVAL_MS);
TelemetrySchedule lightSchedule(SENSOR_UPLOAD_INTERVAL_MS);
bool watchdogConfigured = false;
bool loopWatchdogSubscribed = false;

const IPAddress setupIP(192, 168, 4, 1);
const IPAddress setupSubnet(255, 255, 255, 0);

ProvisioningState provisioningState = ProvisioningState::WaitingForCredentials;
String savedSSID;
String savedPassword;
String targetSSID;
String targetPassword;
String provisioningError;

bool portalRunning = false;
bool routesRegistered = false;
bool connectionQueued = false;
bool saveAfterConnection = false;
bool shutdownScheduled = false;
bool firebaseInitialized = false;
bool resetButtonHeld = false;
bool resetButtonHandled = false;

uint32_t connectionQueuedAt = 0;
uint32_t connectionStartedAt = 0;
uint32_t portalShutdownAt = 0;
uint32_t resetButtonPressedAt = 0;

bool validSSID(const String &ssid) {
  if (ssid.length() == 0 || ssid.length() > 32) return false;
  for (size_t i = 0; i < ssid.length(); ++i) {
    if (ssid[i] == '\0') return false;
  }
  return true;
}

bool validPassword(const String &password) {
  if (password.length() == 0) return true;  // Open network.
  if (password.length() == 64) {
    for (size_t i = 0; i < password.length(); ++i) {
      const char c = password[i];
      if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
            (c >= 'A' && c <= 'F'))) return false;
    }
    return true;
  }
  if (password.length() < 8 || password.length() > 63) return false;
  for (size_t i = 0; i < password.length(); ++i) {
    const unsigned char c = static_cast<unsigned char>(password[i]);
    if (c < 32 || c > 126) return false;
  }
  return true;
}

const char *provisioningStateName() {
  switch (provisioningState) {
    case ProvisioningState::WaitingForCredentials: return "waiting_for_credentials";
    case ProvisioningState::Connecting: return "connecting";
    case ProvisioningState::Connected: return "connected";
    case ProvisioningState::Failed: return "failed";
  }
  return "unknown";
}

void sendJson(int code, const String &json) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(code, "application/json", json);
}

bool loadSavedWiFi() {
  Preferences prefs;
  if (!prefs.begin("wifi", true)) return false;
  SavedWiFi record = {};
  bool validRecord = false;
  if (prefs.getBytesLength("credentials") == sizeof(record)) {
    const size_t bytesRead = prefs.getBytes("credentials", &record, sizeof(record));
    validRecord = bytesRead == sizeof(record) && record.magic == WIFI_RECORD_MAGIC &&
        std::memchr(record.ssid, '\0', sizeof(record.ssid)) != nullptr &&
        std::memchr(record.password, '\0', sizeof(record.password)) != nullptr;
  }
  if (validRecord) {
    savedSSID = String(record.ssid);
    savedPassword = String(record.password);
  } else {
    // Retain compatibility with credentials saved by the original sketch.
    savedSSID = prefs.getString("ssid", "");
    savedPassword = prefs.getString("password", "");
  }
  prefs.end();
  if (!validSSID(savedSSID) || !validPassword(savedPassword)) {
    savedSSID = "";
    savedPassword = "";
    return false;
  }
  return true;
}

bool persistConnectedWiFi() {
  SavedWiFi record = {};
  record.magic = WIFI_RECORD_MAGIC;
  targetSSID.toCharArray(record.ssid, sizeof(record.ssid));
  targetPassword.toCharArray(record.password, sizeof(record.password));
  Preferences prefs;
  if (!prefs.begin("wifi", false)) return false;
  const bool written = prefs.putBytes("credentials", &record, sizeof(record)) == sizeof(record);
  prefs.end();
  if (written) {
    savedSSID = targetSSID;
    savedPassword = targetPassword;
  }
  return written;
}

void cancelScan() {
  if (WiFi.scanComplete() == WIFI_SCAN_RUNNING) esp_wifi_scan_stop();
  WiFi.scanDelete();
}

void queueWiFiConnection(const String &ssid, const String &password, bool saveOnSuccess) {
  targetSSID = ssid;
  targetPassword = password;
  saveAfterConnection = saveOnSuccess;
  provisioningError = "";
  provisioningState = ProvisioningState::Connecting;
  shutdownScheduled = false;
  connectionQueued = true;
  connectionQueuedAt = millis();
  // The loop starts the radio change after the HTTP acknowledgement is sent.
}

void processQueuedConnection() {
  if (!connectionQueued || millis() - connectionQueuedAt < 250) return;
  connectionQueued = false;
  cancelScan();
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false, false);
  WiFi.mode(portalRunning ? WIFI_AP_STA : WIFI_STA);
  WiFi.setMinSecurity(targetPassword.length() == 0 ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK);
  connectionStartedAt = millis();
  WiFi.begin(targetSSID.c_str(), targetPassword.c_str());
  Serial.println("Connecting the device to the selected Wi-Fi network.");
}

void stopSetupPortal() {
  if (!portalRunning) return;
  server.stop();
  dnsServer.stop();
  cancelScan();
  WiFi.softAPdisconnect(false);
  WiFi.mode(WIFI_STA);
  portalRunning = false;
  shutdownScheduled = false;
  Serial.println("Setup portal closed. Normal Wi-Fi operation continues.");
}

void sendDeviceInfo() {
  String json = "{\"apiVersion\":" + YeningWifiScan::quoteJson(API_VERSION);
  json += ",\"deviceId\":" + YeningWifiScan::quoteJson(DEVICE_ID);
  json += ",\"deviceName\":" + YeningWifiScan::quoteJson(DEVICE_NAME);
  json += ",\"deviceTypeId\":" + YeningWifiScan::quoteJson(DEVICE_TYPE);
  json += ",\"deviceType\":" + YeningWifiScan::quoteJson(DEVICE_TYPE);
  // No serial number was supplied. Flutter obtains it from the registry.
  json += ",\"apSsid\":" + YeningWifiScan::quoteJson(SETUP_SSID);
  json += ",\"apIp\":" + YeningWifiScan::quoteJson(setupIP.toString());
  json += ",\"provisioningStatus\":" + YeningWifiScan::quoteJson(provisioningStateName());
  json += '}';
  sendJson(200, json);
}

void sendWiFiStatus() {
  // A previously connected station must not confirm a newly queued attempt.
  const bool connected = provisioningState == ProvisioningState::Connected &&
      !connectionQueued && WiFi.status() == WL_CONNECTED && WiFi.localIP() != IPAddress(0, 0, 0, 0);
  const String ssid = connected ? WiFi.SSID() : targetSSID;
  const String ip = connected ? WiFi.localIP().toString() : String("");
  String json = "{\"deviceId\":" + YeningWifiScan::quoteJson(DEVICE_ID);
  json += ",\"status\":";
  json += YeningWifiScan::quoteJson(connected ? "connected" :
      provisioningState == ProvisioningState::Connected ? "connecting" : provisioningStateName());
  json += ",\"connected\":";
  json += connected ? "true" : "false";
  json += ",\"ssid\":" + YeningWifiScan::quoteJson(ssid);
  json += ",\"ip\":" + YeningWifiScan::quoteJson(ip);
  json += ",\"ipAddress\":" + YeningWifiScan::quoteJson(ip);
  json += ",\"apIp\":" + YeningWifiScan::quoteJson(setupIP.toString());
  json += ",\"error\":" + YeningWifiScan::quoteJson(provisioningError);
  json += '}';
  sendJson(200, json);
}

void handleSaveWiFi() {
  if (provisioningState == ProvisioningState::Connecting) {
    sendJson(409, "{\"error\":\"connection_in_progress\"}");
    return;
  }
  const String ssid = server.arg("ssid");
  const String password = server.arg("password");
  if (!validSSID(ssid) || !validPassword(password)) {
    sendJson(400, "{\"error\":\"invalid_wifi_credentials\"}");
    return;
  }
  queueWiFiConnection(ssid, password, true);
  sendJson(202, "{\"accepted\":true,\"status\":\"connecting\"}");
}

bool startSetupPortal();

bool resetSavedWiFi() {
  Preferences prefs;
  if (!prefs.begin("wifi", false)) return false;
  const bool cleared = prefs.clear();
  prefs.end();
  if (!cleared) return false;
  connectionQueued = false;
  shutdownScheduled = false;
  saveAfterConnection = false;
  savedSSID = "";
  savedPassword = "";
  targetSSID = "";
  targetPassword = "";
  provisioningError = "";
  provisioningState = ProvisioningState::WaitingForCredentials;
  cancelScan();
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false, false);
  if (!portalRunning) startSetupPortal();
  Serial.println("Saved Wi-Fi cleared. The device is ready for setup.");
  return true;
}

void handleResetWiFi() {
  if (resetSavedWiFi()) sendJson(200, "{\"reset\":true}");
  else sendJson(500, "{\"error\":\"storage_error\"}");
}

void redirectToPortal() {
  server.sendHeader("Location", "http://192.168.4.1/", true);
  server.send(302, "text/plain", "");
}

void registerPortalRoutes() {
  if (routesRegistered) return;
  server.on("/", HTTP_GET, []() {
    server.sendHeader("Cache-Control", "no-store");
    server.send_P(200, "text/html; charset=utf-8", SETUP_PORTAL_HTML);
  });
  server.on("/api/device/info", HTTP_GET, sendDeviceInfo);
  server.on("/api/wifi/status", HTTP_GET, sendWiFiStatus);
  server.on("/api/provision/status", HTTP_GET, sendWiFiStatus);
  registerWifiScanApi(server, DEVICE_ID, SETUP_SSID);
  server.on("/save", HTTP_POST, handleSaveWiFi);
  server.on("/api/provision/wifi", HTTP_POST, handleSaveWiFi);
  server.on("/reset", HTTP_POST, handleResetWiFi);
  server.on("/rescan", HTTP_POST, []() {
    if (WiFi.scanComplete() != WIFI_SCAN_RUNNING) WiFi.scanDelete();
    sendJson(200, "{\"accepted\":true}");
  });
  server.on("/generate_204", HTTP_GET, redirectToPortal);
  server.on("/hotspot-detect.html", HTTP_GET, redirectToPortal);
  server.on("/connecttest.txt", HTTP_GET, redirectToPortal);
  server.on("/ncsi.txt", HTTP_GET, redirectToPortal);
  server.onNotFound(redirectToPortal);
  routesRegistered = true;
}

bool startSetupPortal() {
  if (portalRunning) return true;
  WiFi.mode(WIFI_AP_STA);
  if (!WiFi.softAPConfig(setupIP, setupIP, setupSubnet) ||
      !WiFi.softAP(SETUP_SSID, SETUP_PASSWORD)) {
    Serial.println("Could not start setup Wi-Fi.");
    return false;
  }
  dnsServer.start(53, "*", setupIP);
  registerPortalRoutes();
  server.begin();
  portalRunning = true;
  Serial.println("Setup Wi-Fi is ready: Yening-Eco-Setup");
  return true;
}

void failWiFiConnection(const char *reason) {
  provisioningState = ProvisioningState::Failed;
  provisioningError = reason;
  connectionQueued = false;
  shutdownScheduled = false;
  targetPassword = "";
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false, false);
  startSetupPortal();
  Serial.println("Wi-Fi connection failed. Setup remains available for another attempt.");
}

void processProvisioning() {
  if (connectionQueued) return;
  if (provisioningState == ProvisioningState::Connecting) {
    if (WiFi.status() == WL_CONNECTED && WiFi.SSID() == targetSSID &&
        WiFi.localIP() != IPAddress(0, 0, 0, 0)) {
      if (saveAfterConnection && !persistConnectedWiFi()) {
        failWiFiConnection("storage_error");
        return;
      }
      const bool newlyProvisioned = saveAfterConnection;
      saveAfterConnection = false;
      targetPassword = "";
      provisioningState = ProvisioningState::Connected;
      provisioningError = "";
      WiFi.setAutoReconnect(true);
      if (portalRunning) {
        shutdownScheduled = true;
        portalShutdownAt = millis() + (newlyProvisioned ? PORTAL_GRACE_MS : SAVED_WIFI_PORTAL_GRACE_MS);
      }
      Serial.println("Device Wi-Fi connection confirmed.");
    } else if (millis() - connectionStartedAt >= WIFI_JOIN_TIMEOUT_MS) {
      failWiFiConnection("wifi_join_timeout");
    }
  } else if (provisioningState == ProvisioningState::Connected && WiFi.status() != WL_CONNECTED) {
    // Allow the saved station connection to recover before reopening setup.
    provisioningState = ProvisioningState::Connecting;
    targetSSID = savedSSID;
    saveAfterConnection = false;
    shutdownScheduled = false;
    connectionStartedAt = millis();
  }

  if (shutdownScheduled && provisioningState == ProvisioningState::Connected &&
      static_cast<int32_t>(millis() - portalShutdownAt) >= 0) {
    stopSetupPortal();
  }
}

void processResetButton() {
  const bool pressed = digitalRead(RESET_BUTTON_PIN) == LOW;
  if (!pressed) {
    resetButtonHeld = false;
    resetButtonHandled = false;
    return;
  }
  if (!resetButtonHeld) {
    resetButtonHeld = true;
    resetButtonPressedAt = millis();
  }
  if (!resetButtonHandled && millis() - resetButtonPressedAt >= RESET_HOLD_MS) {
    resetButtonHandled = true;
    if (!resetSavedWiFi()) Serial.println("Wi-Fi reset failed: storage unavailable.");
  }
}

String safeFirebaseError(String message) {
  // Keep useful server error codes without exposing the configured credentials.
  const char *secrets[] = {API_KEY, FIREBASE_USER_EMAIL, FIREBASE_USER_PASSWORD};
  for (const char *secret : secrets) {
    if (secret != nullptr && secret[0] != '\0') message.replace(secret, "[redacted]");
  }
  return message;
}

void firebaseTokenCallback(TokenInfo info) {
  if (info.status == token_status_error || info.error.code != 0) {
    Serial.print("Firebase authentication error code: ");
    Serial.println(info.error.code);
    Serial.print("Firebase authentication error message: ");
    Serial.println(safeFirebaseError(info.error.message.c_str()));
  } else if (info.status == token_status_ready) {
    Serial.println("Firebase authentication ready.");
  }
}

void initializeFirebase() {
  if (firebaseInitialized) return;
  if (strlen(FIREBASE_USER_EMAIL) == 0 || strlen(FIREBASE_USER_PASSWORD) == 0) {
    static bool reported = false;
    if (!reported) {
      Serial.println("Device Firebase Authentication credentials are missing in firebase_secrets.h.");
      reported = true;
    }
    return;
  }
  firebaseConfig.api_key = API_KEY;
  firebaseConfig.database_url = DATABASE_URL;
  firebaseConfig.token_status_callback = firebaseTokenCallback;
  firebaseConfig.timeout.socketConnection = 3000;
  firebaseConfig.timeout.serverResponse = FIREBASE_RESPONSE_TIMEOUT_MS;
  firebaseAuth.user.email = FIREBASE_USER_EMAIL;
  firebaseAuth.user.password = FIREBASE_USER_PASSWORD;
  firebaseData.setBSSLBufferSize(4096, 1024);
  firebaseData.setResponseSize(2048);
  // In SDK 4.4.17 config.timeout.sslHandshake is unused. Configure the actual
  // TLS client instead (its public API takes seconds).
  firebaseData.getWiFiClient()->setHandshakeTimeout(FIREBASE_HANDSHAKE_TIMEOUT_SECONDS);
  firebaseData.keepAlive(15, 5, 3);
  // One confirmed attempt per metric; never retry old readings in a backlog.
  Firebase.RTDB.setMaxRetry(&firebaseData, 0);
  Firebase.reconnectWiFi(true);
  Firebase.begin(&firebaseConfig, &firebaseAuth);
  firebaseInitialized = true;
  Serial.println("Firebase client initialized; waiting for device authentication.");
}

float readLightAdc() {
  analogRead(LDR_DATA_PIN);  // Discard the first conversion before averaging.
  uint32_t total = 0;
  for (uint8_t sample = 0; sample < LDR_SAMPLE_COUNT; ++sample) {
    total += analogRead(LDR_DATA_PIN);
    delayMicroseconds(200);
  }
  return static_cast<float>(total) / LDR_SAMPLE_COUNT;
}

void queueMetricReading(TelemetryMetric metric, float value, uint32_t sampledAt,
    float rawAdc = NAN) {
  const MetricReading reading = {value, rawAdc, sampledAt};
  xQueueOverwrite(telemetryQueues[static_cast<uint8_t>(metric)], &reading);
  Serial.printf("%s sample captured at %lu ms.\n", telemetryMetricName(metric),
      static_cast<unsigned long>(sampledAt));
}

void processSensorSampling() {
  if (telemetryConnection == nullptr) return;
  const bool connected = !portalRunning && WiFi.status() == WL_CONNECTED &&
      provisioningState == ProvisioningState::Connected;
  const bool previouslyConnected =
      (xEventGroupGetBits(telemetryConnection) & TELEMETRY_CONNECTED) != 0;
  if (!connected) {
    if (previouslyConnected) {
      xEventGroupClearBits(telemetryConnection, TELEMETRY_CONNECTED);
      for (QueueHandle_t queue : telemetryQueues) xQueueReset(queue);
    }
    return;
  }
  if (!previouslyConnected) {
    dhtSchedule.reset(millis(), true);
    lightSchedule.reset(millis(), true);
    xEventGroupSetBits(telemetryConnection, TELEMETRY_CONNECTED);
  }
  if (dhtSchedule.due(millis())) {
    const uint32_t sampledAt = millis();
    // One DHT22 frame supplies both measurements. Each gets its own queue and
    // cloud record; the physical sensor's two-second cooldown is still enforced.
    const float temperature = dht.readTemperature(false, true);
    const float humidity = dht.readHumidity();
    queueMetricReading(TelemetryMetric::Temperature, temperature, sampledAt);
    queueMetricReading(TelemetryMetric::Humidity, humidity, sampledAt);
  }
  // Light has its own capture schedule; a missing DHT frame cannot postpone it.
  if (lightSchedule.due(millis())) {
    const uint32_t sampledAt = millis();
    const float rawAdc = readLightAdc();
    queueMetricReading(TelemetryMetric::Light,
        lightPercentFromAdc(rawAdc, LDR_DARK_ADC, LDR_BRIGHT_ADC), sampledAt, rawAdc);
  }
}

void logFirebaseServerTiming(TelemetryMetric metric) {
  FirebaseJsonData updatedAt;
  const String field = String("telemetry/") + telemetryMetricName(metric);
  FirebaseJson &response = firebaseData.jsonObject();
  // RTDB normally normalizes the multi-location write response to nested JSON.
  response.get(updatedAt, (field + "/updatedAt").c_str());
  if (!updatedAt.success) {
    // Also accept an echoed literal slash-separated key without interpreting
    // that key as a FirebaseJson path.
    const size_t count = response.iteratorBegin();
    for (size_t index = 0; index < count; ++index) {
      int type;
      String key, value;
      response.iteratorGet(index, type, key, value);
      if (key != field) continue;
      FirebaseJson record;
      record.setJsonData(value);
      record.get(updatedAt, "updatedAt");
      break;
    }
    response.iteratorEnd();
  }
  const bool numeric = updatedAt.typeNum == FirebaseJson::JSON_INT ||
      updatedAt.typeNum == FirebaseJson::JSON_FLOAT ||
      updatedAt.typeNum == FirebaseJson::JSON_DOUBLE;
  if (!updatedAt.success || !numeric) {
    Serial.println("Metric upload confirmed, but the response did not include updatedAt.");
    return;
  }
  const double serverSeen = updatedAt.to<double>();
  if (!isfinite(serverSeen) || serverSeen <= 0) {
    Serial.println("Upload confirmed, but the server timestamp was invalid.");
    return;
  }
  static double previousServerSeen[TELEMETRY_METRIC_COUNT] = {};
  const uint8_t index = static_cast<uint8_t>(metric);
  Serial.printf("%s RTDB updatedAt: %.0f ms.\n", telemetryMetricName(metric), serverSeen);
  if (previousServerSeen[index] > 0 && serverSeen >= previousServerSeen[index]) {
    Serial.printf("%s interval between RTDB updates: %.0f ms (target: %lu ms).\n",
        telemetryMetricName(metric), serverSeen - previousServerSeen[index],
        static_cast<unsigned long>(SENSOR_UPLOAD_INTERVAL_MS));
  }
  previousServerSeen[index] = serverSeen;
}

void uploadTelemetryMetric(TelemetryMetric metric, const MetricReading &reading) {
  const bool valid = validTelemetryReading(metric, reading.value);
  const char *name = telemetryMetricName(metric);
  const String field = String("telemetry/") + name;
  FirebaseJson update;
  FirebaseJson timestamp;
  timestamp.add(".sv", "timestamp");
  // add() preserves literal slash-separated keys for a multi-location PATCH.
  // set() would create a nested telemetry object and replace its siblings.
  update.add("connectivity/isOnline", true);
  update.add("connectivity/lastSeen", timestamp);
  if (valid) {
    FirebaseJson record;
    record.add("value", reading.value);
    record.add("updatedAt", timestamp);
    update.add(field.c_str(), record);
  } else {
    // Delete this whole record. Never attach a new timestamp to an old value.
    update.add(field.c_str());
    Serial.printf("%s reading unavailable; clearing only this metric.\n", name);
  }
  const String path = String("/deviceLive/") + DEVICE_ID;
  const uint32_t uploadStartedAt = millis();
  Serial.printf("Uploading %s captured at %lu ms; sample age: %lu ms.\n", name,
      static_cast<unsigned long>(reading.sampledAt),
      static_cast<unsigned long>(uploadStartedAt - reading.sampledAt));
  // Each request replaces just one metric record and its heartbeat. The value
  // and updatedAt are committed atomically; sibling metric records stay intact.
  // Both modes wait for server confirmation; diagnostics need no extra GET.
  const bool uploaded = FIREBASE_LOG_SERVER_TIMING
      ? Firebase.RTDB.updateNode(&firebaseData, path.c_str(), &update)
      : Firebase.RTDB.updateNodeSilent(&firebaseData, path.c_str(), &update);
  const uint32_t uploadFinishedAt = millis();
  Serial.printf("%s Firebase request duration: %lu ms.\n", name,
      static_cast<unsigned long>(uploadFinishedAt - uploadStartedAt));
  if (uploaded) {
    if (valid && FIREBASE_LOG_SERVER_TIMING) logFirebaseServerTiming(metric);
    if (valid) {
      Serial.printf("%s: %.1f %s; metric uploaded.\n", name, reading.value,
          metric == TelemetryMetric::Temperature ? "C" : "%");
      if (metric == TelemetryMetric::Light) Serial.printf("Light ADC: %.1f.\n", reading.rawAdc);
    } else Serial.printf("%s unavailable record cleared.\n", name);
  } else {
    Serial.printf("Firebase %s upload failed, code: ", name);
    Serial.println(firebaseData.httpCode());
    Serial.print("Firebase telemetry upload error: ");
    Serial.println(safeFirebaseError(firebaseData.errorReason()));
    Serial.println("Other metrics will still be attempted; this metric uses its next fresh reading.");
  }
}

void firebaseUploadTask(void *) {
  // Only this task can feed its own subscription. A healthy sensor loop cannot
  // conceal an uploader stuck in a network call.
  const esp_err_t subscription = watchdogConfigured
      ? subscribeCurrentTaskToWatchdog() : ESP_ERR_INVALID_STATE;
  const bool watchdogSubscribed = subscription == ESP_OK;
  if (watchdogSubscribed) Serial.println("Watchdog monitoring: firebase-upload task.");
  else Serial.printf("Upload task watchdog unavailable, code: %d.\n", subscription);
  for (;;) {
    // Idle/offline/authentication-wait iterations are healthy too. A reboot
    // requires a stalled task, not merely missing Wi-Fi or a rejected login.
    if (watchdogSubscribed) esp_task_wdt_reset();
    const EventBits_t bits = xEventGroupWaitBits(telemetryConnection,
        TELEMETRY_CONNECTED, pdFALSE, pdFALSE, pdMS_TO_TICKS(100));
    if ((bits & TELEMETRY_CONNECTED) == 0 || WiFi.status() != WL_CONNECTED) {
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    // This task exclusively owns every Firebase SDK call, including token
    // refresh. Blocking authentication never runs in the sensor/provisioning loop.
    initializeFirebase();
    if (!firebaseInitialized || !Firebase.ready()) {
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    for (uint8_t index = 0; index < TELEMETRY_METRIC_COUNT; ++index) {
      MetricReading reading;
      if (xQueueReceive(telemetryQueues[index], &reading, 0) != pdTRUE) continue;
      if ((xEventGroupGetBits(telemetryConnection) & TELEMETRY_CONNECTED) == 0 ||
          WiFi.status() != WL_CONNECTED) break;
      if (millis() - reading.sampledAt > SENSOR_UPLOAD_INTERVAL_MS) continue;
      uploadTelemetryMetric(static_cast<TelemetryMetric>(index), reading);
      // Feed only after a request returns; a blocked SDK call remains visible.
      if (watchdogSubscribed) esp_task_wdt_reset();
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("Yening telemetry firmware: independent-metrics-2s-watchdog-v5.");
  const esp_reset_reason_t resetReason = esp_reset_reason();
  if (resetReason == ESP_RST_TASK_WDT || resetReason == ESP_RST_INT_WDT ||
      resetReason == ESP_RST_WDT) {
    Serial.println("Previous restart was caused by a watchdog timeout.");
  }
  const esp_err_t watchdogResult = configureTaskWatchdog(TASK_WATCHDOG_TIMEOUT_SECONDS);
  watchdogConfigured = watchdogResult == ESP_OK;
  if (watchdogConfigured) {
    const esp_err_t subscription = subscribeCurrentTaskToWatchdog();
    loopWatchdogSubscribed = subscription == ESP_OK;
    if (loopWatchdogSubscribed) {
      Serial.printf("Watchdog monitoring: sensor/setup task; timeout: %lu seconds.\n",
          static_cast<unsigned long>(TASK_WATCHDOG_TIMEOUT_SECONDS));
    } else {
      Serial.printf("Sensor task watchdog unavailable, code: %d.\n", subscription);
    }
  } else {
    Serial.printf("Watchdog initialization failed, code: %d.\n", watchdogResult);
  }
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  pinMode(LDR_DATA_PIN, INPUT);
  analogReadResolution(12);
  analogSetPinAttenuation(LDR_DATA_PIN, ADC_11db);
  dht.begin();
  WiFi.persistent(false);
  // Keep the station awake to avoid power-save latency on this Dev Module.
  WiFi.setSleep(false);
  WiFi.setAutoReconnect(false);
  const bool hasSavedWiFi = loadSavedWiFi();
  startSetupPortal();
  if (hasSavedWiFi) queueWiFiConnection(savedSSID, savedPassword, false);
  bool queuesReady = true;
  for (QueueHandle_t &queue : telemetryQueues) {
    queue = xQueueCreate(1, sizeof(MetricReading));
    queuesReady = queuesReady && queue != nullptr;
  }
  telemetryConnection = xEventGroupCreate();
  if (!queuesReady || telemetryConnection == nullptr ||
      xTaskCreate(firebaseUploadTask, "firebase-upload", 16384, nullptr, 1, nullptr) != pdPASS) {
    for (QueueHandle_t &queue : telemetryQueues) {
      if (queue != nullptr) vQueueDelete(queue);
      queue = nullptr;
    }
    if (telemetryConnection != nullptr) vEventGroupDelete(telemetryConnection);
    telemetryConnection = nullptr;
    Serial.println("Unable to start telemetry: insufficient task memory.");
  }
  Serial.println("EnviroSense Basic is running.");
}

void loop() {
  if (portalRunning) {
    dnsServer.processNextRequest();
    server.handleClient();
  }
  processResetButton();
  processQueuedConnection();
  processProvisioning();
  processSensorSampling();
  if (loopWatchdogSubscribed) esp_task_wdt_reset();
  delay(2);
}
