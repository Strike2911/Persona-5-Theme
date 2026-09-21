import {readFile} from 'node:fs/promises';
import {connect} from './cdp.mjs';

export async function buildSource(lite = false) {
  let css = await readFile(new URL('./persona.css', import.meta.url), 'utf8');
  css += '\n' + await readFile(new URL('./persona-v2.css', import.meta.url), 'utf8');
  css += '\n' + await readFile(new URL('./comic.css', import.meta.url), 'utf8');
  const wallpaper = await readFile(new URL('./assets/city-mono.jpg', import.meta.url));
  css += '\nhtml[data-p5-desktop]{--p5-wallpaper:url("data:image/jpeg;base64,' + wallpaper.toString('base64') + '")}';
  const assets = [];
  for (const name of ['wordmark','sidebar-city','comic-edge','chat-badge']) {
    const data = await readFile(new URL(`./assets/${name}.svg`, import.meta.url));
    assets.push(`--p5-${name}:url("data:image/svg+xml;base64,${data.toString('base64')}");`);
  }
  for (const name of ['img', 'img2', 'imgBGW']) {
    const data = await readFile(new URL(`../icons/${name}.svg`, import.meta.url));
    assets.push(`--p5-icon-${name}:url("data:image/svg+xml;base64,${data.toString('base64')}");`);
  }
  css += `\nhtml[data-p5-desktop]{${assets.join('')}}`;
  return `(() => {
    if (location.origin !== 'https://web.whatsapp.com' || window.top !== window) return;
    function install() {
      document.getElementById('p5-desktop-theme')?.remove();
      const style = document.createElement('style');
      style.id = 'p5-desktop-theme';
      style.textContent = ${JSON.stringify(css)};
      document.head.appendChild(style);
      document.documentElement.setAttribute('data-p5-desktop', '1');
      document.documentElement.toggleAttribute('data-p5-lite', ${JSON.stringify(lite)});
      // Observe only the small header, never the message tree. Reuse its photo.
      window.__p5DesktopCleanup?.();
      let photoObserver;
      let structureObserver;
      let observedHeader;
      function portrait() {
        const photo = document.querySelector('[data-testid="conversation-header"] img');
        const src = photo?.getAttribute('src');
        document.documentElement.style.setProperty('--p5-contact-portrait',
          src ? 'url(' + JSON.stringify(src) + ')' : 'none');
      }
      function loaded(event) {
        if (event.target.matches?.('[data-testid="conversation-header"] img')) bindPortrait();
      }
      function bindPortrait() {
        const header = document.querySelector('[data-testid="conversation-header"]');
        if (header !== observedHeader) {
          photoObserver?.disconnect();
          observedHeader = header;
          if (header) {
            photoObserver = new MutationObserver(portrait);
            photoObserver.observe(header, {subtree:true, childList:true, attributes:true, attributeFilter:['src']});
          }
        }
        // Watch only direct children along the header's ancestor chain.
        // React can replace the entire header without loading a new photo.
        structureObserver?.disconnect();
        let parent = header?.parentElement || document.querySelector('#main') || document.querySelector('#app');
        if (parent) {
          structureObserver ||= new MutationObserver(bindPortrait);
          while (parent) {
            structureObserver.observe(parent, {childList:true});
            parent = parent.parentElement;
          }
        }
        portrait();
      }
      document.addEventListener('load', loaded, true);
      window.__p5DesktopCleanup = () => {
        document.removeEventListener('load', loaded, true);
        photoObserver?.disconnect();
        structureObserver?.disconnect();
      };
      bindPortrait();
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', install, {once:true});
    else install();
  })();`;
}

export async function applyTheme(port, lite = false) {
  const source = await buildSource(lite);
  const deadline = Date.now() + 35000;
  let client;
  let lastError;
  while (Date.now() < deadline) {
    try { client = await connect(port); break; }
    catch (error) { lastError = error; await new Promise(resolve => setTimeout(resolve, 700)); }
  }
  if (!client) throw lastError;
  try {
    await client.send('Page.enable');
    await client.send('Page.addScriptToEvaluateOnNewDocument', {source});
    const result = await client.send('Runtime.evaluate', {expression:source});
    if (result.exceptionDetails) throw Error('No se pudo insertar el tema');
    // First activation may expose the page before DOMContentLoaded.
    let installed = false;
    const verifyDeadline = Date.now() + 15000;
    while (Date.now() < verifyDeadline) {
      try {
        const verified = await client.send('Runtime.evaluate', {
          expression: `Boolean(document.getElementById('p5-desktop-theme'))`, returnByValue:true
        });
        if (verified.result?.value) { installed = true; break; }
      } catch (error) {
        if (!/context|navigat/i.test(error.message)) throw error;
      }
      await new Promise(resolve => setTimeout(resolve,250));
    }
    if (!installed) throw Error('No se pudo verificar el tema');
    console.log('Tema Persona 5 aplicado a WhatsApp oficial.');
  } finally { client.close(); }
}

if (process.argv[2]) {
  await applyTheme(Number(process.argv[2]), process.argv.includes('--lite')).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
