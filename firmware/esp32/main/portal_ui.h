#pragma once

#include <Arduino.h>

// Optional browser fallback. Flutter uses the same JSON endpoints.
const char SETUP_PORTAL_HTML[] PROGMEM = R"PORTAL(
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Yening Eco Setup</title>
<style>
body{font:16px system-ui,sans-serif;background:#f4f6f5;color:#17221b;margin:0;padding:24px}
main{max-width:480px;margin:24px auto;padding:24px;background:white;border-radius:16px}
h1{margin-top:0}label{display:block;margin:16px 0 6px}
input,select,button{font:inherit;width:100%;box-sizing:border-box;padding:12px;border-radius:8px}
input,select{border:1px solid #bcc8bf}button{border:0;background:#226b46;color:white;margin-top:16px}
button:disabled{opacity:.6}.secondary{background:#edf3ef;color:#226b46}
#message{white-space:pre-wrap;line-height:1.5}small{color:#526259}
</style></head><body><main>
<h1>Yening Eco</h1><p id="identity">EnviroSense Wi-Fi setup</p>
<form id="wifi"><label for="networks">Nearby Wi-Fi networks</label>
<select id="networks"><option value="">Choose a network</option></select>
<button class="secondary" type="button" id="scan">Scan again</button>
<label for="ssid">Wi-Fi name</label><input id="ssid" name="ssid" required autocomplete="off">
<small>Select a network above, or enter a hidden network's exact name.</small>
<label for="password">Wi-Fi password</label>
<input id="password" name="password" type="password" autocomplete="off">
<small>Leave blank for an open network. Use a 2.4 GHz network.</small>
<button id="connect" type="submit">Connect device</button></form>
<p id="message" role="status">Ready for setup.</p>
<button class="secondary" id="reset" type="button">Reset saved Wi-Fi</button>
</main><script>
const el=id=>document.getElementById(id);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let busy=false,networks=[];
function lock(value){busy=value;for(const id of ['scan','connect','reset','networks','ssid','password'])el(id).disabled=value;}
async function scan(){
  if(busy)return;lock(true);el('message').textContent='Finding nearby networks…';
  try{
    const deadline=Date.now()+25000;let done=false;
    while(Date.now()<deadline){
      const response=await fetch('/api/wifi/networks',{cache:'no-store'});
      if(!response.ok)throw Error('Scan failed. Try again or enter the Wi-Fi name.');
      const data=await response.json();
      if(data.status==='complete'){
        networks=data.networks;el('networks').replaceChildren(new Option('Choose a network',''));
        const seen=new Set();
        for(const network of networks){
          if(seen.has(network.ssid))continue;seen.add(network.ssid);
          const option=new Option(network.ssid+' ('+network.rssi+' dBm, '+network.security+')',network.ssid);
          option.disabled=!network.isSupported;el('networks').add(option);
        }
        el('message').textContent=networks.length?'Choose your Wi-Fi network.':'No networks found. Enter the Wi-Fi name.';
        done=true;break;
      }
      await sleep(700);
    }
    if(!done)throw Error('Scan timed out. Try again or enter the Wi-Fi name.');
  }catch(error){el('message').textContent=error.message;}finally{lock(false);}
}
el('networks').onchange=()=>{
  el('ssid').value=el('networks').value;el('password').value='';
  const network=networks.find(item=>item.ssid===el('networks').value);
  el('password').required=!!network&&!network.isOpen;
};
el('ssid').oninput=()=>{el('password').required=false;};
el('scan').onclick=scan;
el('wifi').onsubmit=async event=>{
  event.preventDefault();if(busy)return;
  const body=new URLSearchParams(new FormData(el('wifi')));
  lock(true);
  el('message').textContent='Connecting device…';
  const requestedSsid=el('ssid').value;
  try{
    const response=await fetch('/save',{method:'POST',body});
    if(!response.ok)throw Error('Check the Wi-Fi name and password.');
    const deadline=Date.now()+30000;let finished=false;
    while(Date.now()<deadline){
      await sleep(1000);
      let data;
      try{const status=await fetch('/api/wifi/status',{cache:'no-store'});data=await status.json();}
      catch(error){continue;}
      if(data.status==='failed')throw Error('Could not connect. Check your Wi-Fi name and password.');
      if(data.connected&&data.ssid===requestedSsid){
        el('message').textContent='Connected to '+data.ssid+'. The setup network will close shortly.';
        el('password').value='';finished=true;break;
      }
    }
    if(!finished)throw Error('Connection could not be confirmed. Try again.');
  }catch(error){el('message').textContent=error.message;}finally{lock(false);}
};
el('reset').onclick=async()=>{
  if(busy||!confirm('Clear saved Wi-Fi credentials?'))return;
  try{const response=await fetch('/reset',{method:'POST'});if(!response.ok)throw Error('Reset failed.');
    el('message').textContent='Saved Wi-Fi cleared. Choose a network to set up again.';
  }catch(error){el('message').textContent=error.message;}
};
fetch('/api/device/info').then(response=>response.json()).then(data=>{
  el('identity').textContent=data.deviceName+' · '+data.deviceId;
}).catch(()=>{});
scan();
</script></body></html>
)PORTAL";
