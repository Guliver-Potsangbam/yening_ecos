#pragma once

#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Firebase_ESP_Client.h>

#include "google_root_certificates.h"

struct FirebaseTokenResponse {
  bool success = false;
  int code = 0;
  String message;
  String idToken;
  String refreshToken;
  uint32_t expiresIn = 0;
};

inline String firebaseFormEncode(const String &value) {
  const char hex[] = "0123456789ABCDEF";
  String encoded;
  for (size_t i = 0; i < value.length(); ++i) {
    const unsigned char c = static_cast<unsigned char>(value[i]);
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~') {
      encoded += static_cast<char>(c);
    } else {
      encoded += '%';
      encoded += hex[c >> 4];
      encoded += hex[c & 15];
    }
  }
  return encoded;
}

inline String firebaseJsonString(FirebaseJson &json, const char *path) {
  FirebaseJsonData result;
  if (!json.get(result, path) || result.type != "string") return "";
  return result.stringValue;
}

// Exactly one HTTPS request. Retry and token renewal are controlled by main.ino,
// avoiding the ESP Client library's blocking password-sign-in retry loop.
inline FirebaseTokenResponse requestFirebaseToken(const char *apiKey,
    const char *email, const char *password, const String &refreshToken) {
  FirebaseTokenResponse result;
  const bool refreshing = refreshToken.length() > 0;
  WiFiClientSecure tls;
  tls.setCACert(GOOGLE_ROOT_CERTIFICATES);
  tls.setHandshakeTimeout(10);
  HTTPClient http;
  http.setConnectTimeout(10000);
  http.setTimeout(10000);
  http.setReuse(false);
  const String url = String(refreshing
      ? "https://securetoken.googleapis.com/v1/token?key="
      : "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") +
      firebaseFormEncode(apiKey);
  if (!http.begin(tls, url)) {
    result.code = -1;
    result.message = "AUTH_HTTP_INITIALIZATION_FAILED";
    return result;
  }

  String body;
  if (refreshing) {
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    body = "grant_type=refresh_token&refresh_token=" + firebaseFormEncode(refreshToken);
  } else {
    http.addHeader("Content-Type", "application/json");
    FirebaseJson credentials;
    credentials.set("email", email);
    credentials.set("password", password);
    credentials.set("returnSecureToken", true);
    credentials.toString(body, false);
  }

  result.code = http.POST(body);
  body = "";
  if (result.code <= 0) {
    result.message = HTTPClient::errorToString(result.code);
    http.end();
    return result;
  }
  if (http.getSize() > 8192) {
    result.message = "AUTH_RESPONSE_TOO_LARGE";
    http.end();
    return result;
  }
  FirebaseJson response;
  const bool parsed = response.setJsonData(http.getString());
  http.end();
  if (!parsed) {
    result.message = "INVALID_AUTH_RESPONSE";
    return result;
  }
  if (result.code != 200) {
    result.message = firebaseJsonString(response, "error/message");
    if (result.message.length() == 0) result.message = "AUTH_REQUEST_REJECTED";
    return result;
  }
  if (firebaseJsonString(response, "mfaPendingCredential").length() > 0) {
    result.message = "MFA_REQUIRED: this account requires a second-factor sign-in flow";
    return result;
  }

  result.idToken = firebaseJsonString(response, refreshing ? "id_token" : "idToken");
  result.refreshToken = firebaseJsonString(response, refreshing ? "refresh_token" : "refreshToken");
  const String expiry = firebaseJsonString(response, refreshing ? "expires_in" : "expiresIn");
  bool validExpiry = expiry.length() > 0 && expiry.length() <= 5;
  for (size_t i = 0; i < expiry.length(); ++i) {
    if (expiry[i] < '0' || expiry[i] > '9') validExpiry = false;
  }
  const long seconds = validExpiry ? expiry.toInt() : 0;
  if (result.idToken.length() == 0 || result.refreshToken.length() == 0 ||
      seconds <= 120 || seconds > 3600) {
    result.idToken = "";
    result.refreshToken = "";
    result.message = "INVALID_AUTH_TOKEN_RESPONSE";
    return result;
  }
  result.expiresIn = static_cast<uint32_t>(seconds);
  result.success = true;
  return result;
}
