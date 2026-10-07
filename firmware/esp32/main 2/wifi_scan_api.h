#pragma once

#include <WiFi.h>
#include <WebServer.h>
#include <memory>

namespace YeningWifiScan {

inline String quoteJson(const String &value) {
  static const char hex[] = "0123456789abcdef";
  String output = "\"";
  for (size_t i = 0; i < value.length(); ++i) {
    const unsigned char c = static_cast<unsigned char>(value[i]);
    if (c == '"' || c == '\\') {
      output += '\\';
      output += static_cast<char>(c);
    } else if (c < 0x20) {
      output += "\\u00";
      output += hex[c >> 4];
      output += hex[c & 0x0f];
    } else {
      output += static_cast<char>(c);
    }
  }
  output += '"';
  return output;
}

inline const char *securityName(wifi_auth_mode_t auth) {
  switch (auth) {
    case WIFI_AUTH_OPEN: return "Open";
    case WIFI_AUTH_WEP: return "WEP";
    case WIFI_AUTH_WPA_PSK: return "WPA";
    case WIFI_AUTH_WPA2_PSK: return "WPA2";
    case WIFI_AUTH_WPA_WPA2_PSK: return "WPA/WPA2";
    case WIFI_AUTH_WPA2_ENTERPRISE: return "Enterprise";
    case WIFI_AUTH_WPA3_PSK: return "WPA3";
    case WIFI_AUTH_WPA2_WPA3_PSK: return "WPA2/WPA3";
    default: return "Other";
  }
}

// This sketch's credential form supports open and WPA2 personal networks.
// Enterprise requires additional credentials; WPA3-only is not promised here.
inline bool supported(wifi_auth_mode_t auth) {
  return auth == WIFI_AUTH_OPEN || auth == WIFI_AUTH_WPA2_PSK ||
      auth == WIFI_AUTH_WPA_WPA2_PSK || auth == WIFI_AUTH_WPA2_WPA3_PSK;
}

struct ScanState {
  bool active = false;
};

}  // namespace YeningWifiScan

// Call once when registering the configuration-portal routes, before
// server.begin(). Requires Arduino-ESP32 2.x/3.x and no additional library.
inline void registerWifiScanApi(WebServer &server, const String &deviceId,
                                const String &setupSsid) {
  auto state = std::make_shared<YeningWifiScan::ScanState>();
  server.on("/api/wifi/networks", HTTP_GET,
      [&server, deviceId, setupSsid, state]() {
    server.sendHeader("Cache-Control", "no-store");
    const String identity = "\"deviceId\":" + YeningWifiScan::quoteJson(deviceId);
    if (!state->active) {
      // Never restart a scan still running after an interrupted client.
      if (WiFi.scanComplete() == WIFI_SCAN_RUNNING) {
        state->active = true;
      } else {
        WiFi.scanDelete();
        const int16_t started = WiFi.scanNetworks(true, false);
        if (started == WIFI_SCAN_FAILED) {
          server.send(503, "application/json",
              "{" + identity + ",\"status\":\"failed\",\"error\":\"scan_failed\"}");
          return;
        }
        state->active = true;
      }
    }

    const int16_t count = WiFi.scanComplete();
    if (count == WIFI_SCAN_RUNNING) {
      server.send(202, "application/json",
          "{" + identity + ",\"status\":\"scanning\",\"networks\":[]}");
      return;
    }
    if (count < 0) {
      state->active = false;
      WiFi.scanDelete();
      server.send(503, "application/json",
          "{" + identity + ",\"status\":\"failed\",\"error\":\"scan_failed\"}");
      return;
    }

    String json = "{" + identity + ",\"status\":\"complete\",\"networks\":[";
    bool first = true;
    int added = 0;
    // ESP32 scan results are sorted by RSSI. Bound payload size and RAM use.
    for (int16_t i = 0; i < count && added < 40; ++i) {
      const String ssid = WiFi.SSID(i);
      if (ssid.length() == 0 || ssid == setupSsid) continue;
      const wifi_auth_mode_t auth = WiFi.encryptionType(i);
      if (!first) json += ',';
      first = false;
      json += "{\"ssid\":" + YeningWifiScan::quoteJson(ssid);
      json += ",\"rssi\":" + String(WiFi.RSSI(i));
      json += ",\"isOpen\":";
      json += auth == WIFI_AUTH_OPEN ? "true" : "false";
      json += ",\"isSupported\":";
      json += YeningWifiScan::supported(auth) ? "true" : "false";
      json += ",\"security\":";
      json += YeningWifiScan::quoteJson(YeningWifiScan::securityName(auth));
      json += '}';
      ++added;
    }
    json += "]}";
    WiFi.scanDelete();
    state->active = false;
    server.send(200, "application/json", json);
  });
}
