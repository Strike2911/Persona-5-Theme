import {readFile} from 'node:fs/promises';
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
  return {available:true,version,url};
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
    console.log(JSON.stringify(await check(current)));
  }catch(error){console.error(error.message);process.exitCode=1;}
}
