import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {installNativeNotifications} from './native-notifications.mjs';
function setup(prefs=null){
 const shown=[],tones=[],sent=[],timers=new Map();let seq=0;
 const helpers={showMessageNotification:d=>shown.push(d),playTone:d=>tones.push(d)};
 const original={...helpers};
 const window={require:()=>helpers,__p5DesktopNotice:p=>sent.push(JSON.parse(p))};
 const context={window,localStorage:{getItem:()=>JSON.stringify(prefs)},setTimeout:fn=>{timers.set(++seq,fn);return seq;},clearTimeout:id=>timers.delete(id)};
 vm.runInNewContext(`(${installNativeNotifications.toString()})()`,context);
 return{shown,tones,sent,timers,helpers,original,window};
}
test('popup acknowledgement retains notification center but suppresses native banner',()=>{
 const e=setup();const d={title:'Example',body:'Example',key:'sample',suppressBanner:false};
 e.helpers.showMessageNotification(d);assert.equal(e.shown.length,0);
 e.window.__p5NativeAck(e.sent[0].id,true);
 assert.equal(e.shown[0].suppressBanner,true);assert.equal(d.suppressBanner,false);
 assert.equal(e.shown[0].key,'sample');assert.equal(e.timers.size,0);
});
test('missing helper, failed popup and timeout preserve native notifications',()=>{
 for(const mode of ['missing','failed','timeout']){
  const e=setup();if(mode==='missing')delete e.window.__p5DesktopNotice;
  const d={title:'example'};e.helpers.showMessageNotification(d);
  if(mode==='failed')e.window.__p5NativeAck(e.sent[0].id,false);
  if(mode==='timeout')[...e.timers.values()][0]();
  assert.equal(e.shown[0],d);
 }
});
test('suppressed notifications are not surfaced; sound fallback and cleanup restore originals',()=>{
 const e=setup();e.helpers.showMessageNotification({suppressBanner:true});assert.equal(e.sent.length,0);
 e.helpers.playTone(4);e.window.__p5NativeAck(e.sent[0].id,true);assert.equal(e.tones.length,0);
 e.helpers.playTone(5);e.window.__p5NativeAck(e.sent[1].id,false);assert.deepEqual(e.tones,[5]);
 e.helpers.playTone(6);e.window.__p5NativeCleanup();assert.deepEqual(e.tones,[5,6]);
 assert.equal(e.helpers.showMessageNotification,e.original.showMessageNotification);
 assert.equal(e.helpers.playTone,e.original.playTone);assert.equal(e.timers.size,0);
});
test('users can hide banners, restore original style and silence sound independently',()=>{
 const hidden=setup({banners:false});hidden.helpers.showMessageNotification({title:'example'});
 assert.equal(hidden.sent.length,0);assert.equal(hidden.shown[0].suppressBanner,true);
 const normal=setup({personaNotices:false});const payload={title:'example'};normal.helpers.showMessageNotification(payload);
 assert.equal(normal.sent.length,0);assert.equal(normal.shown[0],payload);
 const muted=setup({sound:false});muted.helpers.playTone(1);
 assert.equal(muted.sent.length,0);assert.equal(muted.tones.length,0);
});
