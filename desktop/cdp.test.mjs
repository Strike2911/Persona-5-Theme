import test from 'node:test';
import assert from 'node:assert/strict';
import {waitForConnection} from './cdp.mjs';
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
