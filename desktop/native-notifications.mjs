// Version-dependent adapter. No global Windows notification permission required.
export function installNativeNotifications() {
  window.__p5NativeCleanup?.();
  let helpers;
  try{helpers=window.require('WAWebWindowsNotificationHelpers');}catch{return false;}
  if(typeof helpers.showMessageNotification!=='function'||typeof helpers.playTone!=='function')return false;
  const show=helpers.showMessageNotification, tone=helpers.playTone;
  const pending=new Map();let counter=0;
  function send(data,success,failure){
    if(typeof window.__p5DesktopNotice!=='function'){failure();return;}
    const id=String(++counter)+'-'+Date.now();
    const timer=setTimeout(()=>{pending.delete(id);failure();},1500);
    pending.set(id,{timer,success,failure});
    try{window.__p5DesktopNotice(JSON.stringify({...data,id}));}catch{clearTimeout(timer);pending.delete(id);failure();}
  }
  window.__p5NativeAck=(id,ok)=>{const item=pending.get(id);if(!item)return;pending.delete(id);clearTimeout(item.timer);(ok?item.success:item.failure)();};
  function prefs(){try{const p=JSON.parse(localStorage.getItem('p5-effects-v1'));return{enabled:p?.sound!==false,volume:p?.volume??.35,banners:p?.banners!==false,persona:p?.personaNotices!==false};}catch{return{enabled:true,volume:.35,banners:true,persona:true};}}
  function themedShow(data){
    if(data.suppressBanner)return show.apply(this,arguments);
    const p=prefs();
    if(!p.banners)return show.call(this,{...data,suppressBanner:true});
    if(!p.persona)return show.apply(this,arguments);
    const self=this,args=arguments;
    send({kind:'notice',title:String(data.title||'WhatsApp').slice(0,100),body:String(data.body||'Nuevo mensaje').slice(0,240)},
      ()=>show.call(self,{...data,suppressBanner:true}),()=>show.apply(self,args));
  }
  function themedTone(){
    const self=this,args=arguments,p=prefs();
    if(!p.enabled)return;
    send({kind:'tone',volume:Math.max(0,Math.min(1,Number(p.volume)||0))},()=>{},()=>tone.apply(self,args));
  }
  helpers.showMessageNotification=themedShow;helpers.playTone=themedTone;
  window.__p5NativeCleanup=()=>{
    if(helpers.showMessageNotification===themedShow)helpers.showMessageNotification=show;
    if(helpers.playTone===themedTone)helpers.playTone=tone;
    for(const item of pending.values()){clearTimeout(item.timer);item.failure();}pending.clear();
    delete window.__p5NativeAck;delete window.__p5NativeCleanup;
  };
  return true;
}
