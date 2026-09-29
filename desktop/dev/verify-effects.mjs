// Isolated, invisible fixture: never adds messages to the real conversation.
import {connect} from '../cdp.mjs';
import {installEffects,createMessageTracker} from '../effects.mjs';
const c=await connect(Number(process.argv[2]));
try {
  const fixture=`(async()=>{
    let tick=Date.now(); Date.now=()=>tick;
    const played=[]; window.Audio=class{constructor(src){this.src=src;}play(){played.push(this.src);return Promise.resolve();}pause(){}load(){}removeAttribute(){}};
    let native=0; HTMLMediaElement.prototype.play=function(){native++;return Promise.resolve();};
    document.hasFocus=()=>true;
    Object.defineProperty(document,'hidden',{value:false});
    document.body.innerHTML='<div data-testid="conversation-info-header-chat-title">fixture</div><div data-testid="conversation-panel-messages"></div><div data-testid="chat-list"><div data-testid="cell-frame-container"><div data-testid="cell-frame-title"><span title="fixture-other"></span></div><span aria-label="0 unread messages"></span></div></div>';
    const panel=document.querySelector('[data-testid="conversation-panel-messages"]');
    const marker=document.querySelector('[aria-label]');
    const make=(id,old=false)=>{const row=document.createElement('div');row.dataset.id=id;
      const date=new Date();if(old)date.setDate(date.getDate()-1);
      const stamp='['+date.getHours()+':'+String(date.getMinutes()).padStart(2,'0')+', '+date.getDate()+'/'+(date.getMonth()+1)+'/'+date.getFullYear()+']';
      row.innerHTML='<div data-testid="msg-container"><div class="x1ew7x2d"><span data-pre-plain-text="'+stamp+'"></span></div></div>';return row;};
    panel.appendChild(make('baseline'));
    const fx=(${installEffects.toString()})({chat:'inside',other:'outside'},${createMessageTracker.toString()});
    const wait=()=>new Promise(r=>setTimeout(r,180));
    await wait();if(played.length)throw Error('baseline sounded');
    tick+=2000;panel.appendChild(make('new'));await wait();
    if(played.join()!=='inside')throw Error('incoming sound failed: '+played);
    tick+=1000;panel.appendChild(make('new'));panel.appendChild(make('old',true));await wait();
    if(played.length!==1)throw Error('duplicate or history sounded');
    const notification=document.createElement('audio');notification.src='https://static.whatsapp.net/rsrc.php/yW/r/BS_BUUXbKq5.mp3';await notification.play();
    if(played.join()!=='inside,outside')throw Error('other-chat sound failed: '+played);
    if(native!==0)throw Error('native notification also played');
    const voice=document.createElement('audio');voice.src='blob:voice-note';await voice.play();
    if(native!==1)throw Error('voice playback intercepted');
    fx.cleanup(); tick+=1000;panel.appendChild(make('after-cleanup'));await wait();
    await notification.play();if(native!==2)throw Error('native sound not restored');
    if(played.length!==2||document.getElementById('p5-sound-controls'))throw Error('cleanup failed');
    return {baselineSilent:true,inside:true,outside:true,nativeReplaced:true,voiceUntouched:true,deduplicated:true,historySilent:true,cleaned:true};
  })()`;
  await c.send('Runtime.evaluate',{expression:`{const f=document.createElement('iframe');f.id='p5-effects-fixture';f.name='p5-effects-fixture';f.style.display='none';document.body.appendChild(f);}`});
  const tree=await c.send('Page.getFrameTree');
  const frame=tree.frameTree.childFrames.find(f=>f.frame.name==='p5-effects-fixture');
  if(!frame)throw Error('Missing fixture frame');
  const world=await c.send('Page.createIsolatedWorld',{frameId:frame.frame.id,worldName:'p5-effects-test'});
  const result=await c.send('Runtime.evaluate',{expression:fixture,contextId:world.executionContextId,awaitPromise:true,returnByValue:true});
  if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
  console.log(JSON.stringify(result.result.value));
}finally{await c.send('Runtime.evaluate',{expression:`document.getElementById('p5-effects-fixture')?.remove()`});c.close();}
