#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include <DHT.h>
#include <esp_wifi.h>
#include <cstring>
#include <ctime>

#include "device_config.h"
#include "firebase_secrets.h"
#include "firebase_auth_client.h"
#include "firebase_auth_retry.h"
#include "wifi_scan_api.h"
#include "portal_ui.h"

// ESP32 Dev Module + DHT22 on GPIO 4.
// All Flutter endpoints are registered here, including asynchronous Wi-Fi scans.
// No sensor values are invented and Wi-Fi passwords are never printed.

WebServer server(80);
DNSServer dnsServer;
DHT dht(DHT_DATA_PIN, DHT22);
FirebaseData firebaseData;
FirebaseAuth firebaseAuth;
FirebaseConfig firebaseConfig;
FirebaseAuthRetry firebaseAuthRetry;
String firebaseRefreshToken;
uint32_t firebaseTokenIssuedAt = 0;
uint32_t firebaseTokenLifetimeMs = 0;

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
bool firebaseClockStarted = false;
bool resetButtonHeld = false;
bool resetButtonHandled = false;

uint32_t connectionQueuedAt = 0;
uint32_t connectionStartedAt = 0;
uint32_t portalShutdownAt = 0;
uint32_t lastUploadAt = 0;
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
  const char *secrets[] = {API_KEY, FIREBASE_USER_EMAIL, FIREBASE_USER_PASSWORD,
      firebaseRefreshToken.c_str()};
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
    firebaseAuthRetry.onError(millis(), info.error.code, info.error.message.c_str());
  } else if (info.status == token_status_ready) {
    Serial.println("Firebase authentication ready.");
  }
}

void initializeFirebase() {
  if (firebaseInitialized) return;
  firebaseConfig.api_key = API_KEY;
  firebaseConfig.database_url = DATABASE_URL;
  firebaseConfig.token_status_callback = firebaseTokenCallback;
  // Only validated ID tokens go to the SDK. Password sign-in and refresh use
  // one REST request at a time, with explicit backoff after failures.
  firebaseConfig.cert.data = GOOGLE_ROOT_CERTIFICATES;
  firebaseData.setBSSLBufferSize(4096, 1024);
  firebaseData.setResponseSize(2048);
  Firebase.reconnectWiFi(true);
  firebaseInitialized = true;
  Serial.println("Firebase sign-in configured; authentication must complete before telemetry uploads.");
}

bool ensureFirebaseAuthentication() {
  initializeFirebase();
  if (!firebaseClockStarted) {
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    firebaseClockStarted = true;
    Serial.println("Waiting for clock synchronization before verified Firebase HTTPS.");
  }
  const time_t now = time(nullptr);
  if (now < 1704067200) return false;  // Do not bypass certificate verification.
  if (!firebaseAuthRetry.canAttempt(millis())) return false;
  if (firebaseTokenLifetimeMs > 0 &&
      millis() - firebaseTokenIssuedAt < firebaseTokenLifetimeMs) return true;

  const FirebaseTokenResponse token = requestFirebaseToken(API_KEY,
      FIREBASE_USER_EMAIL, FIREBASE_USER_PASSWORD, firebaseRefreshToken);
  if (!token.success) {
    Serial.print("Firebase authentication error code: ");
    Serial.println(token.code);
    Serial.print("Firebase authentication error message: ");
    Serial.println(safeFirebaseError(token.message));
    const uint32_t cooldown = firebaseAuthRetry.onError(millis(), token.code, token.message.c_str());
    if (token.message == "INVALID_REFRESH_TOKEN" || token.message == "TOKEN_EXPIRED") {
      firebaseRefreshToken = "";
    }
    if (cooldown == 0) {
      Serial.println("Firebase authentication paused until account configuration is corrected and the device restarts.");
    } else {
      Serial.print("Firebase authentication paused; next attempt in ");
      Serial.print(cooldown / 1000);
      Serial.println(" seconds. Firebase controls when a temporary block expires.");
    }
    return false;
  }

  firebaseRefreshToken = token.refreshToken;
  firebaseTokenIssuedAt = millis();
  firebaseTokenLifetimeMs = (token.expiresIn - 120) * 1000UL;
  Firebase.setSystemTime(time(nullptr));
  // Keep the refresh token in our request controller so the SDK cannot start
  // its own password retries or renew tokens outside the cooldown policy.
  Firebase.setIdToken(&firebaseConfig, token.idToken.c_str(), token.expiresIn);
  Firebase.begin(&firebaseConfig, &firebaseAuth);
  firebaseAuthRetry.onSuccess();
  Serial.println("Firebase authentication ready.");
  return true;
}

void processSensorUpload() {
  // Firebase authentication can block. Finish app provisioning before starting
  // cloud work so local identity, scans, and connection polling stay responsive.
  if (portalRunning || WiFi.status() != WL_CONNECTED ||
      provisioningState != ProvisioningState::Connected) return;
  if (!ensureFirebaseAuthentication()) return;
  if (!Firebase.ready() || millis() - lastUploadAt < SENSOR_UPLOAD_INTERVAL_MS) return;
  lastUploadAt = millis();

  const float temperature = dht.readTemperature();
  const float humidity = dht.readHumidity();
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("DHT22 read failed; no fabricated reading will be uploaded.");
    return;
  }
  FirebaseJson update;
  update.set("connectivity/isOnline", true);
  update.set("connectivity/lastSeen/.sv", "timestamp");
  update.set("telemetry/temperature", temperature);
  update.set("telemetry/humidity", humidity);
  const String path = String("/deviceLive/") + DEVICE_ID;
  if (Firebase.RTDB.updateNode(&firebaseData, path.c_str(), &update)) {
    Serial.print("DHT22: ");
    Serial.print(temperature, 1);
    Serial.print(" C, ");
    Serial.print(humidity, 1);
    Serial.println(" %; telemetry uploaded.");
  } else {
    Serial.print("Firebase telemetry upload failed, code: ");
    Serial.println(firebaseData.httpCode());
    Serial.print("Firebase telemetry upload error: ");
    Serial.println(safeFirebaseError(firebaseData.errorReason()));
    Serial.println("Telemetry will be retried on the next sensor interval.");
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  dht.begin();
  WiFi.persistent(false);
  WiFi.setAutoReconnect(false);
  const bool hasSavedWiFi = loadSavedWiFi();
  startSetupPortal();
  if (hasSavedWiFi) queueWiFiConnection(savedSSID, savedPassword, false);
  lastUploadAt = millis();
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
  processSensorUpload();
  delay(2);
}
