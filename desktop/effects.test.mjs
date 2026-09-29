import test from 'node:test';
import assert from 'node:assert/strict';
import {createMessageTracker} from './effects.mjs';

test('history, outgoing and undated rows are silent; arrivals are deduplicated',()=>{
  const t=createMessageTracker();
  assert.equal(t.ingest([{id:'old',incoming:true,recent:true}],true).length,0);
  assert.equal(t.ingest([{id:'old',incoming:true,recent:true},{id:'sent',incoming:false,recent:true},{id:'history',incoming:true,recent:false}]).length,0);
  assert.deepEqual(t.ingest([{id:'new',incoming:true,recent:true}]).map(r=>r.id),['new']);
  assert.equal(t.ingest([{id:'new',incoming:true,recent:true}]).length,0);
});
test('scroll suppression seeds the baseline and memory is bounded',()=>{
  const t=createMessageTracker(2);
  t.ingest([{id:'a'},{id:'b'}],true);t.ingest([{id:'c'}],true);
  assert.equal(t.ingest([{id:'b',incoming:true,recent:true}]).length,0);
  assert.equal(t.ingest([{id:'a',incoming:true,recent:true}]).length,1);
});
