import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline';
import {connect} from './cdp.mjs';
import {installNativeNotifications} from './native-notifications.mjs';
const c=await connect(Number(process.argv[2]));
const child=spawn(fileURLToPath(new URL('./NotificationPopup.exe',import.meta.url)),[],{windowsHide:true,stdio:['pipe','pipe','ignore']});
let mainContext,ending=false;
const timers=new Set();
async function stop(){if(ending)return;ending=true;for(const t of timers)clearTimeout(t);
  try{await c.send('Runtime.evaluate',{expression:'window.__p5NativeCleanup?.()'});}catch{}
  child.stdin.end();c.close();}
child.on('error',()=>void stop());child.on('exit',()=>void stop());
const lines=createInterface({input:child.stdout});
lines.on('line',line=>{try{const ack=JSON.parse(line);
 if(ack.action==='hide-banners')void c.send('Runtime.evaluate',{expression:`(()=>{let p={};try{p=JSON.parse(localStorage.getItem('p5-effects-v1'))||{}}catch{};p.banners=false;localStorage.setItem('p5-effects-v1',JSON.stringify(p));window.dispatchEvent(new Event('p5-preferences'));})()`}).catch(()=>{});
 if(typeof ack.id==='string')void c.send('Runtime.evaluate',{expression:`window.__p5NativeAck?.(${JSON.stringify(ack.id)},${ack.ok===true})`}).catch(()=>{});
}catch{}});
c.on('Runtime.bindingCalled',event=>{
  if(event.name!=='__p5DesktopNotice'||event.executionContextId!==mainContext||ending)return;
  try{const d=JSON.parse(event.payload);if(typeof d.id!=='string'||!['notice','tone'].includes(d.kind))return;
    const safe={id:d.id.slice(0,80),kind:d.kind,title:String(d.title||'').slice(0,100),body:String(d.body||'').slice(0,240),volume:Math.max(0,Math.min(1,Number(d.volume)||0))};
    child.stdin.write(JSON.stringify(safe)+'\n');
  }catch{}
});
async function install(){if(ending)return;try{await c.send('Runtime.evaluate',{expression:`window.__p5NativeCleanup ? true : (${installNativeNotifications.toString()})()`});}catch{}}
c.on('Runtime.executionContextCreated',event=>{if(event.context.auxData?.isDefault&&event.context.origin==='https://web.whatsapp.com'){
  mainContext=event.context.id;for(const ms of [0,2000,6000]){const t=setTimeout(()=>{timers.delete(t);void install();},ms);timers.add(t);}
}});
c.on('Runtime.executionContextsCleared',()=>{mainContext=undefined;});
c.on('Inspector.detached',()=>void stop());
await c.send('Runtime.addBinding',{name:'__p5DesktopNotice'});
await c.send('Runtime.enable');
await install();
// Quit with WhatsApp; the websocket close event also ends the helper.
c.on('P5.connectionClosed',()=>void stop());
