from pathlib import Path
import re
import subprocess
import tempfile
import sys

root = Path(__file__).resolve().parents[2]
source = (root / 'firmware/esp32/main/main.ino').read_text()
config = (root / 'firmware/esp32/main/device_config.h').read_text()

# Execute the actual firmware state transitions with deterministic radio/NVS
# stand-ins. This does not emulate ESP32 radio channels or hardware timing.
def function(name):
    start = source.index('void ' + name + '(')
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

names = ['queueWiFiConnection', 'failWiFiConnection', 'processProvisioning', 'processResetButton']
constants = '\n'.join(re.findall(r'constexpr uint(?:8|32)_t (?:RESET_BUTTON_PIN|RESET_HOLD_MS|WIFI_JOIN_TIMEOUT_MS|PORTAL_GRACE_MS|SAVED_WIFI_PORTAL_GRACE_MS|WIFI_EDIT_PORTAL_GRACE_MS|WIFI_ROLLBACK_DELAY_MS).*?;', config))
prefix = r'''
#include <cassert>
#include <cstdint>
#include <string>
#include <iostream>
using String = std::string;
constexpr int LOW = 0;
constexpr int HIGH = 1;
constexpr int WL_CONNECTED = 3;
uint32_t clockMs = 0;
uint32_t millis() { return clockMs; }
int button = HIGH;
int digitalRead(int) { return button; }
struct IPAddress {
  bool valid = false;
  IPAddress(bool state):valid(state){}
  IPAddress(int,int,int,int){}
  bool operator!=(const IPAddress &other) const { return valid != other.valid; }
};
struct Radio {
  bool connected = true;
  String ssid = "Old network";
  bool validIP = true;
  int status() { return connected ? WL_CONNECTED : 0; }
  String SSID() { return ssid; }
  IPAddress localIP() { return IPAddress(validIP); }
  void setAutoReconnect(bool) {}
  void disconnect(bool,bool) { connected = false; }
} WiFi;
struct Logger { void println(const char*) {} } Serial;
enum class ProvisioningState { WaitingForCredentials, Connecting, Connected, Failed };
ProvisioningState provisioningState = ProvisioningState::Connected;
bool portalRunning=false, connectionQueued=false, saveAfterConnection=false;
bool shutdownScheduled=false, rollbackPending=false, resetButtonHeld=false, resetButtonHandled=false;
uint32_t rollbackAt=0, connectionQueuedAt=0, connectionStartedAt=0, portalShutdownAt=0, resetButtonPressedAt=0;
String savedSSID="Old network", savedPassword="old-password", targetSSID, targetPassword, provisioningError;
int saves = 0;
bool persistOK = true;
bool validSSID(const String &s) { return !s.empty(); }
void cancelScan() {}
bool startSetupPortal() { portalRunning=true; return true; }
void stopSetupPortal() { portalRunning=false; shutdownScheduled=false; }
bool persistConnectedWiFi() {
  saves++;
  if (!persistOK) return false;
  savedSSID=targetSSID; savedPassword=targetPassword;
  return true;
}
'''
tests = r'''
int main() {
  button=LOW; processResetButton();
  clockMs=4999; processResetButton(); assert(!portalRunning);
  clockMs=5000; processResetButton();
  assert(portalRunning && WiFi.connected && saves==0);
  assert(savedSSID=="Old network" && savedPassword=="old-password");
  assert(shutdownScheduled && portalShutdownAt==305000);
  button=HIGH; processResetButton();

  queueWiFiConnection("Wrong network","wrong-password",true);
  assert(savedSSID=="Old network" && saves==0);
  connectionQueued=false; WiFi.connected=false; connectionStartedAt=clockMs;
  clockMs+=WIFI_JOIN_TIMEOUT_MS; processProvisioning();
  assert(provisioningState==ProvisioningState::Failed && rollbackPending && portalRunning);
  assert(savedSSID=="Old network" && saves==0);
  clockMs+=WIFI_ROLLBACK_DELAY_MS-1; processProvisioning(); assert(!connectionQueued);
  clockMs++; processProvisioning();
  assert(connectionQueued && targetSSID=="Old network" && targetPassword=="old-password");
  assert(!saveAfterConnection && !rollbackPending);

  // A fresh retry cancels a scheduled restoration.
  rollbackPending=true;
  queueWiFiConnection("New network","new-password",true);
  assert(!rollbackPending && savedSSID=="Old network");
  connectionQueued=false; connectionStartedAt=clockMs;
  WiFi.connected=true; WiFi.ssid="New network"; WiFi.validIP=false;
  processProvisioning(); assert(saves==0 && savedSSID=="Old network");
  WiFi.validIP=true; processProvisioning();
  assert(saves==1 && savedSSID=="New network" && savedPassword=="new-password");
  assert(provisioningState==ProvisioningState::Connected);
  assert(shutdownScheduled && portalShutdownAt==clockMs+PORTAL_GRACE_MS);

  // A router outage reopens setup after the existing join timeout.
  stopSetupPortal(); WiFi.connected=false; processProvisioning();
  assert(provisioningState==ProvisioningState::Connecting);
  clockMs+=WIFI_JOIN_TIMEOUT_MS; processProvisioning();
  assert(portalRunning && provisioningState==ProvisioningState::Failed && !rollbackPending);

  // Restoration deadlines remain correct across the millis() rollover.
  clockMs=0xfffffff0U; saveAfterConnection=true;
  failWiFiConnection("timeout");
  clockMs+=WIFI_ROLLBACK_DELAY_MS-1; processProvisioning(); assert(!connectionQueued);
  clockMs++; processProvisioning(); assert(connectionQueued);
  assert(savedSSID=="New network");
  std::cout << "Wi-Fi recovery host checks passed.\n";
}
'''
with tempfile.TemporaryDirectory(prefix='yening-wifi-recovery-') as directory:
    folder = Path(directory)
    cpp = folder / 'recovery.cpp'
    cpp.write_text(prefix + '\n' + constants + '\n' + '\n'.join(function(name) for name in names) + '\n' + tests)
    binary = folder / 'recovery'
    flags = []
    if sys.platform == 'darwin':
        sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
        flags = ['-isysroot', sdk, '-isystem', f'{sdk}/usr/include/c++/v1']
    subprocess.run(['c++', '-std=c++17', *flags, str(cpp), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
