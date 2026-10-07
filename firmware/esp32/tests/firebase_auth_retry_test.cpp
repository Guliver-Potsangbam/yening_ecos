#include "../main/firebase_auth_retry.h"

#include <cassert>
#include <cstdio>

int main() {
  FirebaseAuthRetry retry;
  assert(retry.canAttempt(0));
  assert(retry.onError(100, 400, "TOO_MANY_ATTEMPTS_TRY_LATER") == 900000);
  assert(!retry.canAttempt(900099));
  assert(retry.canAttempt(900100));
  // The generic follow-up callback cannot shorten or extend the first pause.
  assert(retry.onError(200, 400, "bad request") == 900000);
  assert(retry.canAttempt(900100));
  assert(retry.onError(900100, 400, "TOO_MANY_ATTEMPTS_TRY_LATER") == 1800000);
  assert(retry.onError(2700100, 429, "") == 3600000);
  assert(retry.onError(6300100, 400, "TOO_MANY_ATTEMPTS_TRY_LATER") == 3600000);
  retry.onSuccess();
  assert(retry.canAttempt(6300101));
  assert(retry.onError(6300101, -1, "connection refused") == 30000);
  assert(retry.onError(6330101, -1, "connection refused") == 60000);
  // Upgrade a short connection-error pause if a throttle is reported later.
  assert(retry.onError(6330102, 400, "TOO_MANY_ATTEMPTS_TRY_LATER") == 900000);
  assert(!retry.canAttempt(7230101));
  assert(retry.canAttempt(7230102));
  retry.onSuccess();
  uint32_t now = UINT32_MAX - 100;
  assert(retry.onError(now, -1, "timeout") == 30000);
  assert(!retry.canAttempt(static_cast<uint32_t>(now + 29999)));
  assert(retry.canAttempt(static_cast<uint32_t>(now + 30000)));
  for (int i = 0; i < 10; ++i) {
    now += 300000;
    assert(retry.canAttempt(now));
    assert(retry.onError(now, -1, "timeout") <= 300000);
  }
  // Wrong credentials and an unsupported MFA flow must not keep signing in.
  retry.onSuccess();
  assert(retry.onError(10, 400, "INVALID_LOGIN_CREDENTIALS") == 0);
  assert(!retry.canAttempt(10000000));
  assert(retry.onError(20, 400, "bad request") == 0);
  retry.onSuccess();
  assert(retry.canAttempt(20));
  assert(retry.onError(20, 200, "MFA_REQUIRED: second factor required") == 0);
  assert(!retry.canAttempt(10000000));
  puts("Firebase authentication cooldown checks passed.");
}
