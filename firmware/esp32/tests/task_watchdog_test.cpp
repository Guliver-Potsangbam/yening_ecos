#include <cassert>

#include "../main/task_watchdog.h"

static esp_err_t initializationResult = ESP_OK;
static esp_err_t subscriptionStatus = ESP_ERR_NOT_FOUND;
static esp_err_t subscriptionResult = ESP_OK;
static unsigned int subscriptions = 0;

#if ESP_IDF_VERSION_MAJOR >= 5
static esp_task_wdt_config_t configuration = {};
static unsigned int reconfigurations = 0;
static esp_err_t reconfigurationResult = ESP_OK;

esp_err_t esp_task_wdt_init(const esp_task_wdt_config_t *config) {
  configuration = *config;
  return initializationResult;
}
esp_err_t esp_task_wdt_reconfigure(const esp_task_wdt_config_t *config) {
  configuration = *config;
  ++reconfigurations;
  return reconfigurationResult;
}
#else
static uint32_t configuredSeconds = 0;
static bool panicEnabled = false;

esp_err_t esp_task_wdt_init(uint32_t timeoutSeconds, bool panic) {
  configuredSeconds = timeoutSeconds;
  panicEnabled = panic;
  return initializationResult;
}
#endif

esp_err_t esp_task_wdt_status(TaskHandle_t task) {
  assert(task == nullptr);  // Must check the currently executing task.
  return subscriptionStatus;
}
esp_err_t esp_task_wdt_add(TaskHandle_t task) {
  assert(task == nullptr);  // Must subscribe that task, not another task's handle.
  ++subscriptions;
  return subscriptionResult;
}

int main() {
  assert(configureTaskWatchdog(30) == ESP_OK);
#if ESP_IDF_VERSION_MAJOR >= 5
  assert(configuration.timeout_ms == 30000);
  assert(configuration.trigger_panic);
  assert(configuration.idle_core_mask == 1);
  assert(reconfigurations == 0);
  initializationResult = ESP_ERR_INVALID_STATE;
  assert(configureTaskWatchdog(30) == ESP_OK);
  assert(reconfigurations == 1);
  reconfigurationResult = ESP_ERR_NO_MEM;
  assert(configureTaskWatchdog(30) == ESP_ERR_NO_MEM);
#else
  assert(configuredSeconds == 30);
  assert(panicEnabled);
#endif
  // Initialization failures are surfaced rather than reported as protection.
  initializationResult = ESP_ERR_NO_MEM;
  assert(configureTaskWatchdog(30) == ESP_ERR_NO_MEM);
  assert(subscribeCurrentTaskToWatchdog() == ESP_OK);
  assert(subscriptions == 1);
  // An already subscribed Arduino loop must not be registered twice.
  subscriptionStatus = ESP_OK;
  assert(subscribeCurrentTaskToWatchdog() == ESP_OK);
  assert(subscriptions == 1);
  subscriptionStatus = ESP_ERR_NOT_FOUND;
  subscriptionResult = ESP_ERR_NO_MEM;
  assert(subscribeCurrentTaskToWatchdog() == ESP_ERR_NO_MEM);
  assert(subscriptions == 2);
}
