import {readFile, mkdir, open, rename, rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
export const repo = 'Strike2911/Persona-5-Theme';
export function versionParts(value) {
  if (typeof value !== 'string' || !/^\d{1,5}\.\d{1,5}\.\d{1,5}$/.test(value)) throw Error('Version no valida');
  return value.split('.').map(Number);
}
export function newer(candidate, current) {
  const a=versionParts(candidate), b=versionParts(current);
  for(let i=0;i<3;i++) {if(a[i]!==b[i])return a[i]>b[i];} return false;
}
export function selectRelease(release, current) {
  versionParts(current);
  if (!release || release.draft || release.prerelease) return {available:false};
  const version = /^v(\d{1,5}\.\d{1,5}\.\d{1,5})$/.exec(release.tag_name)?.[1];
  if (!version || !newer(version,current)) return {available:false};
  const url=`https://github.com/${repo}/releases/tag/v${version}`;
  if(release.html_url!==url)throw Error('Destino de actualizacion inesperado');
  const name='WhatsApp-Persona5-Instalar.exe';
  const asset=release.assets?.find(a=>a.name===name && a.state==='uploaded');
  if(!asset || asset.browser_download_url!==`https://github.com/${repo}/releases/download/v${version}/${name}`) return {available:false};
  if (!/^sha256:[a-f0-9]{64}$/i.test(asset.digest ?? '')) throw Error('GitHub no proporciona una huella SHA256 valida para el instalador');
  if (!Number.isSafeInteger(asset.size) || asset.size < 1 || asset.size > 100*1024*1024) throw Error('Tamano del instalador no valido');
  return {available:true,version,url,downloadUrl:asset.browser_download_url,sha256:asset.digest.slice(7).toLowerCase(),size:asset.size};
}
export async function download(release, directory, fetchImpl=fetch) {
  versionParts(release.version);
  if (release.downloadUrl !== `https://github.com/${repo}/releases/download/v${release.version}/WhatsApp-Persona5-Instalar.exe` || !/^[a-f0-9]{64}$/.test(release.sha256) || !Number.isSafeInteger(release.size) || release.size < 1 || release.size > 100*1024*1024) throw Error('Paquete de actualizacion no valido');
  await mkdir(directory,{recursive:true});
  const target=join(directory,'WhatsApp-Persona5-Instalar.exe'), partial=target+'.part';
  const response=await fetchImpl(release.downloadUrl,{signal:AbortSignal.timeout(180000)});
  if (!response.ok || !response.body) throw Error('No se pudo descargar el instalador');
  const finalUrl=new URL(response.url || release.downloadUrl);
  if (finalUrl.protocol!=='https:' || !['github.com','release-assets.githubusercontent.com'].includes(finalUrl.hostname)) throw Error('Servidor de descarga inesperado');
  const file=await open(partial,'wx');
  try {
    const hash=createHash('sha256'); let size=0;
    for await (const chunk of response.body) {
      size+=chunk.length;
      if(size>release.size) throw Error('La descarga excede el tamano publicado');
      hash.update(chunk); await file.writeFile(chunk);
    }
    if(size!==release.size || hash.digest('hex')!==release.sha256) throw Error('La descarga esta incompleta o su SHA256 no coincide');
    await file.close(); await rename(partial,target); return target;
  } catch(error) { await file.close().catch(()=>{}); await rm(partial,{force:true}).catch(()=>{}); throw error; }
}
export async function check(current, fetchImpl=fetch) {
  const response=await fetchImpl(`https://api.github.com/repos/${repo}/releases/latest`,{
    signal:AbortSignal.timeout(10000),headers:{'User-Agent':'Persona5ThemeUpdater','Accept':'application/vnd.github+json'}
  });
  if(response.status===404)return {available:false};
  if(!response.ok)throw Error('GitHub no esta disponible ('+response.status+')');
  return selectRelease(await response.json(),current);
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  try {
    const current=JSON.parse((await readFile(new URL('./version.json',import.meta.url),'utf8')).replace(/^\uFEFF/,'')).version;
    const release=await check(current);
    if (release.available && process.argv[2]==='--download') {
      if (!process.argv[3]) throw Error('Falta la carpeta de descarga');
      release.installer=await download(release,process.argv[3]);
    }
    console.log(JSON.stringify(release));
  }catch(error){console.error(error.message);process.exitCode=1;}
}
