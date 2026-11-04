import test from 'node:test';
import assert from 'node:assert/strict';
import {waitForConnection, connect} from './cdp.mjs';
function clock(connectImpl) {let time=0;return {connectImpl,now:()=>time,sleep:async ms=>{time+=ms;}};}
test('local connection waits for delayed WhatsApp and returns the ready client',async()=>{
  let attempts=0;const client={ready:true};
  const result=await waitForConnection(1234,3000,clock(async()=>{if(++attempts<3)throw new TypeError('fetch failed');return client;}));
  assert.equal(result,client);assert.equal(attempts,3);
});
test('unavailable local port ends with a bounded, classified error and underlying cause',async()=>{
  let attempts=0;
  await assert.rejects(waitForConnection(1234,1400,clock(async()=>{attempts++;throw new TypeError('fetch failed',{cause:{code:'ECONNREFUSED'}});})),
    error=>error.code==='P5_CONNECT_TIMEOUT'&&error.message.includes('ECONNREFUSED'));
  assert.equal(attempts,2);
});
test('unsafe debug destination is not retried or converted to a timeout',async()=>{
  let attempts=0;const error=Object.assign(Error('unsafe'),{code:'P5_UNSAFE_ENDPOINT'});
  await assert.rejects(waitForConnection(1234,3000,clock(async()=>{attempts++;throw error;})),e=>e===error);
  assert.equal(attempts,1);
});

test('a closed debug target rejects pending and new commands immediately',async t=>{
  let socket;
  class TestSocket extends EventTarget {
    static OPEN=1;
    readyState=1;
    constructor(){super();socket=this;queueMicrotask(()=>this.dispatchEvent(new Event('open')));}
    send(){}
    close(){this.readyState=3;this.dispatchEvent(new Event('close'));}
  }
  t.mock.method(globalThis,'fetch',async()=>({json:async()=>[
    {id:'page-1',type:'page',url:'https://web.whatsapp.com',webSocketDebuggerUrl:'ws://127.0.0.1:1234/devtools/page/1'}
  ]}));
  t.mock.property(globalThis,'WebSocket',TestSocket);
  const client=await connect(1234);
  const pending=client.send('Runtime.evaluate');
  socket.close();
  await assert.rejects(pending,e=>e.code==='P5_CONNECTION_CLOSED');
  await assert.rejects(client.send('Page.enable'),e=>e.code==='P5_CONNECTION_CLOSED');
});
