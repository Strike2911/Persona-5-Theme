import test from 'node:test';
import assert from 'node:assert/strict';
import {installSource} from './apply-theme.mjs';

function fixture(handlers) {
  let time=0, connections=0;
  const calls=[], closed=[];
  return {calls,closed, options:{
    now:()=>time, sleep:async ms=>{time+=ms;},
    connectImpl:async()=>{
      const index=connections++, handler=handlers[Math.min(index,handlers.length-1)];
      return {targetId:handler.targetId || 'page-1', close:()=>closed.push(index), send:async(method,params)=>{
        calls.push({index,method,params});
        return handler(method,params,index);
      }};
    }
  }};
}
const ready=(method,params)=>params?.returnByValue ? {result:{value:true}} : {};
const contextError=()=>Object.assign(Error('Cannot find default execution context'),{code:'P5_CDP_ERROR'});

test('login page without an execution context is retried without duplicate reload scripts',async()=>{
  let evaluations=0;
  const f=fixture([(method,params)=>{if(method==='Runtime.evaluate' && ++evaluations===1)throw contextError();return ready(method,params);}]);
  await installSource(1234,'source',3000,f.options);
  assert.equal(f.calls.filter(c=>c.method==='Page.addScriptToEvaluateOnNewDocument').length,1);
  assert.deepEqual(f.closed,[0]);
});

test('Windows replacing the debug target during verification reconnects and installs in the new page',async()=>{
  const first=(method,params)=>{if(params?.returnByValue)throw Object.assign(Error('WhatsApp se cerro'),{code:'P5_CONNECTION_CLOSED'});return {};};
  const second=Object.assign(ready,{targetId:'replacement-page'});
  const f=fixture([first,second]);
  await installSource(1234,'source',3000,f.options);
  assert.equal(f.calls.filter(c=>c.method==='Page.addScriptToEvaluateOnNewDocument').length,2);
  assert.deepEqual(f.closed,[0,1]);
});

test('DOMContentLoaded can finish after injection while verification waits',async()=>{
  let checks=0;
  const f=fixture([(method,params)=>params?.returnByValue ? {result:{value:++checks===3}} : {}]);
  await installSource(1234,'source',3000,f.options);
  assert.equal(checks,3);
  assert.deepEqual(f.closed,[0]);
});

test('repeated context failures terminate with the retryable launcher exit classification',async()=>{
  const f=fixture([()=>{throw contextError();}]);
  await assert.rejects(installSource(1234,'source',1400,f.options),e=>e.code==='P5_CONNECT_TIMEOUT');
  assert.equal(f.closed.length,3);
});

test('a page that never installs the theme also has a bounded retry deadline',async()=>{
  const f=fixture([()=>({result:{value:false}})]);
  await assert.rejects(installSource(1234,'source',1400,f.options),e=>e.code==='P5_CONNECT_TIMEOUT');
  assert.deepEqual(f.closed,[0]);
});

test('script errors and unrelated CDP failures are reported immediately',async()=>{
  for(const handler of [
    (method)=>method==='Runtime.evaluate'?{exceptionDetails:{text:'broken script'}}:{},
    ()=>{throw Object.assign(Error('Permission denied'),{code:'P5_CDP_ERROR'});}
  ]) {
    const f=fixture([handler]);
    await assert.rejects(installSource(1234,'source',3000,f.options));
    assert.deepEqual(f.closed,[0]);
  }
});

test('unsafe endpoints cannot be turned into a startup retry',async()=>{
  let attempts=0;
  const error=Object.assign(Error('unsafe'),{code:'P5_UNSAFE_ENDPOINT'});
  await assert.rejects(installSource(1234,'source',3000,{connectImpl:async()=>{attempts++;throw error;}}),e=>e===error);
  assert.equal(attempts,1);
});
