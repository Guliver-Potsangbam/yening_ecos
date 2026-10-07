#pragma once

#include <cstdint>
#include <cstring>

// Cooldowns are local retry policy, not a promise about Firebase's unblock time.
class FirebaseAuthRetry {
 public:
  bool canAttempt(uint32_t now) const {
    return !configurationBlocked_ &&
        (!waiting_ || static_cast<uint32_t>(now - startedAt_) >= waitMs_);
  }

  uint32_t onError(uint32_t now, int code, const char *message) {
    const char *configurationErrors[] = {"INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS",
        "EMAIL_NOT_FOUND", "USER_DISABLED", "USER_NOT_FOUND", "OPERATION_NOT_ALLOWED",
        "API_KEY_INVALID", "API key not valid", "MFA_REQUIRED"};
    for (const char *error : configurationErrors) {
      if (message != nullptr && std::strstr(message, error) != nullptr) {
        configurationBlocked_ = true;
      }
    }
    if (configurationBlocked_) return 0;  // Retrying cannot repair account configuration.
    const bool throttled = code == 429 ||
        (message != nullptr && std::strstr(message, "TOO_MANY_ATTEMPTS_TRY_LATER") != nullptr);
    // Some clients report one server error twice. Never shorten its cooldown.
    if (!canAttempt(now) && (!throttled || rateLimited_)) return waitMs_;
    rateLimited_ = rateLimited_ || throttled;
    waitMs_ = rateLimited_ ? nextThrottleMs_ : nextTransientMs_;
    if (rateLimited_) {
      nextThrottleMs_ = cappedDouble(nextThrottleMs_, 60UL * 60UL * 1000UL);
    } else {
      nextTransientMs_ = cappedDouble(nextTransientMs_, 5UL * 60UL * 1000UL);
    }
    startedAt_ = now;
    waiting_ = true;
    return waitMs_;
  }

  void onSuccess() {
    configurationBlocked_ = false;
    waiting_ = false;
    rateLimited_ = false;
    nextTransientMs_ = 30000;
    nextThrottleMs_ = 15UL * 60UL * 1000UL;
  }

 private:
  static uint32_t cappedDouble(uint32_t value, uint32_t cap) {
    return value >= cap / 2 ? cap : value * 2;
  }

  bool waiting_ = false;
  bool configurationBlocked_ = false;
  bool rateLimited_ = false;
  uint32_t startedAt_ = 0;
  uint32_t waitMs_ = 0;
  uint32_t nextTransientMs_ = 30000;
  uint32_t nextThrottleMs_ = 15UL * 60UL * 1000UL;
};
