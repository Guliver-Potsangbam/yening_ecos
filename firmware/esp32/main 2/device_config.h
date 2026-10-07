#pragma once

#include <Arduino.h>

// Matches the Flutter app and the identity in the supplied sketch.
constexpr char DEVICE_ID[] = "YEC-DEV-000001";
constexpr char DEVICE_TYPE[] = "envirosense_basic_v1";
constexpr char DEVICE_NAME[] = "EnviroSense Basic";
constexpr char SETUP_SSID[] = "Yening-Eco-Setup";
constexpr char SETUP_PASSWORD[] = "12345678";
constexpr char API_VERSION[] = "1";

constexpr uint8_t DHT_DATA_PIN = 4;
constexpr uint8_t LDR_DATA_PIN = 34;  // ADC1 works while Wi-Fi is connected.
constexpr uint8_t LDR_SAMPLE_COUNT = 16;
// This sensor's ADC reading falls as light increases: dark -> 0%, bright -> 100%.
// Full-scale starting references; measured endpoints can refine calibration.
constexpr uint16_t LDR_DARK_ADC = 4095;
constexpr uint16_t LDR_BRIGHT_ADC = 0;
static_assert(LDR_SAMPLE_COUNT > 0 && LDR_SAMPLE_COUNT <= 64, "Invalid LDR sample count");
static_assert(LDR_DARK_ADC != LDR_BRIGHT_ADC, "LDR reference readings must differ");
static_assert(LDR_DARK_ADC <= 4095 && LDR_BRIGHT_ADC <= 4095, "LDR references must fit the 12-bit ADC");
constexpr uint8_t RESET_BUTTON_PIN = 0;  // The Dev Module's BOOT button.
constexpr uint32_t RESET_HOLD_MS = 5000;
constexpr uint32_t WIFI_JOIN_TIMEOUT_MS = 20000;
constexpr uint32_t PORTAL_GRACE_MS = 30000;
constexpr uint32_t SAVED_WIFI_PORTAL_GRACE_MS = 120000;
constexpr uint32_t SENSOR_UPLOAD_INTERVAL_MS = 5000;
constexpr uint32_t FIREBASE_RESPONSE_TIMEOUT_MS = 2000;
constexpr uint32_t FIREBASE_HANDSHAKE_TIMEOUT_SECONDS = 3;
// Include the server-resolved heartbeat in the write response for diagnostics.
// No extra database read or write is needed to measure actual RTDB intervals.
constexpr bool FIREBASE_LOG_SERVER_TIMING = true;

enum class ProvisioningState {
  WaitingForCredentials,
  Connecting,
  Connected,
  Failed,
};

// One NVS value stores the complete credential pair atomically.
struct SavedWiFi {
  uint32_t magic;
  char ssid[33];
  char password[65];
};
constexpr uint32_t WIFI_RECORD_MAGIC = 0x59454331;
