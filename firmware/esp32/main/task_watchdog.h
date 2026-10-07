#pragma once

#include <esp_idf_version.h>
#include <esp_task_wdt.h>
#include <sdkconfig.h>

// Arduino-ESP32 2.x uses IDF 4; 3.x uses the IDF 5 configuration API.
// Configure once in setup(), before subscribing the application tasks.
inline esp_err_t configureTaskWatchdog(uint32_t timeoutSeconds) {
#if ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t config = {};
  config.timeout_ms = timeoutSeconds * 1000;
  // Preserve the SDK's configured idle-task monitoring when reconfiguring.
#if defined(CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU0) && CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU0
  config.idle_core_mask |= 1U;
#endif
#if defined(CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU1) && CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU1
  config.idle_core_mask |= 2U;
#endif
  config.trigger_panic = true;
  const esp_err_t result = esp_task_wdt_init(&config);
  return result == ESP_ERR_INVALID_STATE ? esp_task_wdt_reconfigure(&config) : result;
#else
  // This API also reconfigures an already initialized watchdog.
  return esp_task_wdt_init(timeoutSeconds, true);
#endif
}

inline esp_err_t subscribeCurrentTaskToWatchdog() {
  // Arduino may already have subscribed its loop task.
  if (esp_task_wdt_status(nullptr) == ESP_OK) return ESP_OK;
  return esp_task_wdt_add(nullptr);
}
