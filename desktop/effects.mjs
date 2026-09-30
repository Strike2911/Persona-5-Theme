// No message text is stored: IDs stay in bounded memory for duplicate detection.
export function createMessageTracker(limit = 2000) {
  const seen = new Set();
  return {
    ingest(records, baseline = false) {
      const fresh = [];
      for (const record of records) {
        if (!record.id || seen.has(record.id)) continue;
        seen.add(record.id);
        if (!baseline && record.incoming && record.recent) fresh.push(record);
      }
      while (seen.size > limit) seen.delete(seen.values().next().value);
      return fresh;
    }
  };
}

export function installEffects(config, createTracker) {
  if (!document.body) return {bind(){}, cleanup(){}};
  const tracker = createTracker();
  const key = 'p5-effects-v1';
  let prefs = {sound:true, clicks:true, volume:0.35, banners:true, personaNotices:true};
  try { const saved=JSON.parse(localStorage.getItem(key));
    if (saved) prefs={sound:saved.sound!==false, clicks:saved.clicks!==false, banners:saved.banners!==false,personaNotices:saved.personaNotices!==false,volume:Number.isFinite(saved.volume)?Math.max(0,Math.min(1,saved.volume)):.35};
  } catch {}
  const audio = Object.fromEntries(Object.entries(config).map(([name,src]) => {
    const a=new Audio(src); a.preload='auto'; return [name,a];
  }));
  let lastSound=0, lastWasClick=false, quietUntil=Date.now()+1800, disposed=false;
  let messagePanel, chatKey;
  let lastScroll=0;
  const motion=new Set();
  const pendingSounds=new Map();
  function save(){try{localStorage.setItem(key,JSON.stringify(prefs));}catch{}}
  function play(name, click=false) {
    if (!prefs.sound || (click&&!prefs.clicks) || (Date.now()-lastSound<(click?100:250) && (click||!lastWasClick))) return Promise.resolve();
    lastSound=Date.now();lastWasClick=click;
    for(const a of Object.values(audio)) a.pause();
    const a=audio[name]; a.volume=prefs.volume; a.currentTime=0;
    // WebView may require the first user gesture. Never override autoplay policy.
    return a.play().catch(()=>{});
  }
  // Replace only WhatsApp's known notification asset, never calls/voice notes.
  const media=HTMLMediaElement.prototype, originalPlay=media.play;
  function themedPlay(...args){
    let notification=false;
    try {const u=new URL(this.currentSrc||this.src); notification=u.origin==='https://static.whatsapp.net'&&u.pathname==='/rsrc.php/yW/r/BS_BUUXbKq5.mp3';}catch{}
    if(!notification || disposed) return originalPlay.apply(this,args);
    return new Promise(resolve=>{
      const timer=setTimeout(()=>{pendingSounds.delete(timer);play('other').finally(resolve);},80);
      pendingSounds.set(timer,resolve);
    });
  }
  media.play=themedPlay;
  function recent(row) {
    const stamp=row.querySelector('[data-pre-plain-text]')?.getAttribute('data-pre-plain-text');
    const match=stamp?.match(/^\[([^,]+),\s*(\d{1,4})[\/.\-](\d{1,2})[\/.\-](\d{1,4})\]/);
    if(!match) return false;
    const now=new Date(), a=+match[2],b=+match[3],c=+match[4];
    const year=now.getFullYear(), month=now.getMonth()+1, day=now.getDate();
    if(!((c===year||c===year%100)&&((a===day&&b===month)||(a===month&&b===day))) && !(a===year&&b===month&&c===day)) return false;
    const clock=match[1].replace(/[.\s\u200e\u200f]/g,'').toLowerCase().match(/^(\d{1,2}):(\d{2})(am|pm)?$/);
    if(!clock) return false;
    let hours=+clock[1]; if(clock[3]) hours=hours%12+(clock[3]==='pm'?12:0);
    const time=new Date(year,now.getMonth(),day,hours,+clock[2]).getTime();
    return Date.now()-time>=0 && Date.now()-time<90000;
  }
  function records(nodes) {
    return [...nodes].filter(row=>row.querySelector('[data-pre-plain-text]')).map(row=>({id:row.getAttribute('data-id'), incoming:!!row.querySelector('.x1ew7x2d'), recent:recent(row), node:row.querySelector('[data-testid="msg-container"]')}));
  }
  function entrance(node) {
    if(!node || document.hidden || !document.hasFocus() || document.documentElement.hasAttribute('data-p5-lite') || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const a=node.animate([
      {opacity:0,transform:'translate(-24px, 7px) rotate(-2deg) scale(.94)'},
      {opacity:1,transform:'translate(3px, -1px) rotate(.5deg) scale(1.015)',offset:.72},
      {opacity:1,transform:'none'}
    ],{duration:240,easing:'cubic-bezier(.16,.8,.25,1)'});
    motion.add(a); a.finished.catch(()=>{}).finally(()=>motion.delete(a));
  }
  const messageObserver=new MutationObserver(changes=>{
    const rows=new Set();
    for(const change of changes) for(const node of change.addedNodes) {
      if(node.nodeType!==1) continue;
      const owner=node.closest('[data-id]'); if(owner) rows.add(owner);
      for(const row of node.querySelectorAll('[data-id]')) rows.add(row);
    }
    const baseline=Date.now()<quietUntil || Date.now()-lastScroll<1200;
    const arrivals=tracker.ingest(records(rows),baseline);
    if(!arrivals.length) return;
    for(const r of arrivals.slice(-3)) entrance(r.node);
    if(document.hasFocus()&&!document.hidden)play('chat');
  });
  function bind(){
    if(disposed)return;
    const panel=document.querySelector('[data-testid="conversation-panel-messages"]');
    const title=document.querySelector('[data-testid="conversation-info-header-chat-title"]')?.textContent;
    if(panel!==messagePanel || title!==chatKey){
      messageObserver.disconnect(); messagePanel=panel; chatKey=title; quietUntil=Date.now()+1500;
      if(panel){tracker.ingest(records(panel.querySelectorAll('[data-id]')),true);messageObserver.observe(panel,{childList:true,subtree:true});}
    }
  }
  function scroll(event){if(messagePanel?.contains(event.target)||event.target===messagePanel)lastScroll=Date.now();}
  function click(event){
    if(!event.isTrusted || event.target.closest('#p5-sound-controls'))return;
    if(event.target.closest('[data-testid="cell-frame-container"], [data-navbar-item], [data-testid="filter-button"]'))play('chat',true);
  }
  function stopMotion(){for(const a of motion)a.cancel();motion.clear();}
  // Small local controls; preferences contain no chat data.
  const controls=document.createElement('details'); controls.id='p5-sound-controls';
  controls.innerHTML='<summary title="Opciones Persona 5">♪ P5</summary><div><strong>OPCIONES PERSONA 5</strong><label><input type="checkbox" data-option="banners"> Mostrar avisos en escritorio</label><label><input type="checkbox" data-option="personaNotices"> Usar estilo Persona 5</label><label><input type="checkbox" data-option="sound"> Activar sonidos</label><label><input type="checkbox" data-option="clicks"> Clic al cambiar de chat</label><label>Volumen <input type="range" min="0" max="100" aria-label="Volumen Persona 5"></label><button type="button">Probar sonido</button><small>Sin estilo Persona 5 se usan los avisos normales de WhatsApp. Ocultar avisos conserva los mensajes en el centro de notificaciones.</small></div>';
  for(const name of ['sound','clicks','banners','personaNotices']){const input=controls.querySelector('[data-option="'+name+'"]');input.checked=prefs[name];input.onchange=()=>{prefs[name]=input.checked;save();};}
  function reloadPrefs(){try{const saved=JSON.parse(localStorage.getItem(key));if(saved){prefs={...prefs,...saved};for(const name of ['sound','clicks','banners','personaNotices'])controls.querySelector('[data-option="'+name+'"]').checked=prefs[name]!==false;}}catch{}}
  window.addEventListener('p5-preferences',reloadPrefs);
  const volume=controls.querySelector('[type="range"]');volume.value=prefs.volume*100;volume.oninput=()=>{prefs.volume=Number(volume.value)/100;save();};
  controls.querySelector('button').onclick=()=>play('chat');document.body.appendChild(controls);
  document.addEventListener('click',click,true);document.addEventListener('scroll',scroll,true);
  window.addEventListener('blur',stopMotion);document.addEventListener('visibilitychange',stopMotion);
  bind();
  return {bind,cleanup(){disposed=true;messageObserver.disconnect();stopMotion();
    window.removeEventListener('p5-preferences',reloadPrefs);
    if(media.play===themedPlay)media.play=originalPlay;
    for(const [timer,resolve]of pendingSounds){clearTimeout(timer);resolve();}pendingSounds.clear();
    document.removeEventListener('click',click,true);document.removeEventListener('scroll',scroll,true);
    window.removeEventListener('blur',stopMotion);document.removeEventListener('visibilitychange',stopMotion);
    for(const a of Object.values(audio)){a.pause();a.removeAttribute('src');a.load();}controls.remove();}};
}
