import test from 'node:test';
import assert from 'node:assert/strict';
import {newer,selectRelease,check,repo} from './updater.mjs';
const release=(version='1.3.0')=>({tag_name:'v'+version,draft:false,prerelease:false,
  html_url:`https://github.com/${repo}/releases/tag/v${version}`,
  assets:[{name:'WhatsApp-Persona5-Instalar.exe',state:'uploaded',browser_download_url:`https://github.com/${repo}/releases/download/v${version}/WhatsApp-Persona5-Instalar.exe`}]});
test('numeric ordering, no equal versions or downgrades',()=>{
  assert.equal(newer('1.10.0','1.9.9'),true);assert.equal(newer('2.0.0','1.99.99'),true);
  assert.equal(newer('1.2.0','1.2.0'),false);assert.equal(newer('1.1.0','1.2.0'),false);
  assert.throws(()=>newer('../bad','1.2.0'));
});
test('only complete stable releases notify',()=>{
  assert.equal(selectRelease(release(),'1.2.0').available,true);
  for(const change of [{draft:true},{prerelease:true},{tag_name:'v1.3.0-beta'},{assets:[]}])
    assert.equal(selectRelease({...release(),...change},'1.2.0').available,false);
  assert.equal(selectRelease(release('1.2.0'),'1.2.0').available,false);
});
test('release and download targets cannot leave the chosen repository',()=>{
  assert.throws(()=>selectRelease({...release(),html_url:'https://evil.example'},'1.2.0'));
  const altered=release();altered.assets[0].browser_download_url='https://evil.example/setup.exe';
  assert.equal(selectRelease(altered,'1.2.0').available,false);
});
test('empty repo is quiet; network and rate-limit failures propagate',async()=>{
  assert.deepEqual(await check('1.2.0',async()=>({status:404})),{available:false});
  await assert.rejects(check('1.2.0',async()=>({ok:false,status:403})));
  await assert.rejects(check('1.2.0',async()=>{throw Error('offline')}));
  assert.equal((await check('1.2.0',async(url,options)=>{
    assert.equal(url,`https://api.github.com/repos/${repo}/releases/latest`);
    assert.ok(options.signal);return {ok:true,json:async()=>release()};
  })).available,true);
});
