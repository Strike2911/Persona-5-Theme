import test from 'node:test';
import assert from 'node:assert/strict';
import {newer,selectRelease,check,repo,download} from './updater.mjs';
const release=(version='1.3.0')=>({tag_name:'v'+version,draft:false,prerelease:false,
  html_url:`https://github.com/${repo}/releases/tag/v${version}`,
  assets:[{name:'WhatsApp-Persona5-Instalar.exe',state:'uploaded',size:4,digest:'sha256:'+ 'a'.repeat(64),browser_download_url:`https://github.com/${repo}/releases/download/v${version}/WhatsApp-Persona5-Instalar.exe`}]});
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

test('automatic updates require published digest and bounded size',()=>{
  for(const fields of [{digest:null},{digest:'sha256:bad'},{size:0},{size:200*1024*1024}]) {
    const item=release();Object.assign(item.assets[0],fields);
    assert.throws(()=>selectRelease(item,'1.2.0'));
  }
});
test('download verifies bytes and removes partial files on corrupt or interrupted responses',async()=>{
  const {mkdtemp,readFile,readdir,rm}=await import('node:fs/promises');
  const {tmpdir}=await import('node:os');
  const {join}=await import('node:path');
  const {createHash}=await import('node:crypto');
  const bytes=Buffer.from('test');
  const item=release();item.assets[0].digest='sha256:'+createHash('sha256').update(bytes).digest('hex');
  const selected=selectRelease(item,'1.2.0');
  for(const mode of ['ok','wrong-hash','truncated','oversized','interrupted','redirect','http-error']) {
    const directory=await mkdtemp(join(tmpdir(),'p5-download-test-'));
    try {
      const response=async()=>({ok:mode!=='http-error',url:mode==='redirect'?'https://evil.example/file':'https://release-assets.githubusercontent.com/file',body:(async function*(){
        if(mode==='interrupted'){yield bytes.subarray(0,2);throw Error('connection lost');}
        yield mode==='wrong-hash'?Buffer.from('xxxx'):mode==='truncated'?bytes.subarray(0,2):mode==='oversized'?Buffer.from('toolong'):bytes;
      })()});
      if(mode==='ok')assert.deepEqual(await readFile(await download(selected,directory,response)),bytes);
      else {await assert.rejects(download(selected,directory,response));assert.deepEqual(await readdir(directory),[]);}
    } finally {await rm(directory,{recursive:true,force:true});}
  }
});
