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
constexpr uint8_t RESET_BUTTON_PIN = 0;  // The Dev Module's BOOT button.
constexpr uint32_t RESET_HOLD_MS = 5000;
constexpr uint32_t WIFI_JOIN_TIMEOUT_MS = 20000;
constexpr uint32_t PORTAL_GRACE_MS = 30000;
constexpr uint32_t SAVED_WIFI_PORTAL_GRACE_MS = 120000;
constexpr uint32_t SENSOR_UPLOAD_INTERVAL_MS = 5000;

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
