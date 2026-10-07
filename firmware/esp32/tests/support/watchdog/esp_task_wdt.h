#pragma once

#include <stdint.h>
#include "esp_idf_version.h"

using esp_err_t = int;
constexpr esp_err_t ESP_OK = 0;
constexpr esp_err_t ESP_ERR_INVALID_STATE = 1;
constexpr esp_err_t ESP_ERR_NOT_FOUND = 2;
constexpr esp_err_t ESP_ERR_NO_MEM = 3;
using TaskHandle_t = void *;

#if ESP_IDF_VERSION_MAJOR >= 5
struct esp_task_wdt_config_t {
  uint32_t timeout_ms;
  uint32_t idle_core_mask;
  bool trigger_panic;
};
esp_err_t esp_task_wdt_init(const esp_task_wdt_config_t *config);
esp_err_t esp_task_wdt_reconfigure(const esp_task_wdt_config_t *config);
#else
esp_err_t esp_task_wdt_init(uint32_t timeoutSeconds, bool panic);
#endif
esp_err_t esp_task_wdt_status(TaskHandle_t task);
esp_err_t esp_task_wdt_add(TaskHandle_t task);
