import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {stat} from 'node:fs/promises';
import {buildSource} from './apply-theme.mjs';
test('la ilustracion queda por debajo del limite de las variables CSS', async () => {
  const image = await stat(new URL('./assets/city-mono.jpg',import.meta.url));
  // Chromium rejects custom-property values larger than roughly 1 MiB.
  assert.ok(Math.ceil(image.size / 3) * 4 < 750000);
});

function environment(origin = 'https://web.whatsapp.com', readyState = 'complete') {
  const elements = new Map();
  const attributes = new Map();
  const listeners = new Map();
  const windowListeners = new Map();
  const window = {
    addEventListener:(name,fn)=>windowListeners.set(name,fn),
    removeEventListener:(name,fn)=>{if(windowListeners.get(name)===fn) windowListeners.delete(name);}
  }; window.top = window;
  return {
    location:{origin}, window, elements, attributes, listeners, windowListeners,
    document:{readyState,
      querySelector:() => null,
      getElementById:id => elements.get(id),
      createElement:() => ({remove(){elements.delete(this.id);}}),
      head:{appendChild:el => elements.set(el.id,el)},
      documentElement:{style:{setProperty(){}},setAttribute:(key,value) => attributes.set(key,value), toggleAttribute:(key,on) => on ? attributes.set(key,'') : attributes.delete(key)},
      addEventListener:(name,fn) => listeners.set(name,fn),
      removeEventListener:(name,fn) => { if(listeners.get(name)===fn) listeners.delete(name); }
    }
  };
}
test('solo cambia el origen oficial y nunca subframes', async () => {
  const source = await buildSource();
  const other = environment('https://example.com'); vm.runInNewContext(source,other);
  assert.equal(other.elements.size,0);
  const frame = environment(); frame.window.top = {}; vm.runInNewContext(source,frame);
  assert.equal(frame.elements.size,0);
});
test('reaplicar reemplaza el estilo y respeta modo ligero', async () => {
  const context = environment();
  vm.runInNewContext(await buildSource(),context);
  vm.runInNewContext(await buildSource(true),context);
  assert.equal(context.elements.size,1);
  assert.equal(context.attributes.has('data-p5-lite'),true);
  assert.match(context.elements.get('p5-desktop-theme').textContent,/data:image\/svg\+xml;base64/);
  vm.runInNewContext(await buildSource(false),context);
  assert.equal(context.attributes.has('data-p5-lite'),false);
});
test('se instala al terminar el documento y no programa trabajo continuo', async () => {
  const source = await buildSource();
  const context = environment('https://web.whatsapp.com','loading');
  vm.runInNewContext(source,context);
  assert.equal(context.elements.size,0);
  context.listeners.get('DOMContentLoaded')();
  assert.equal(context.elements.size,1);
  // Without a conversation header there is no observer, timer or rAF work.
});
test('el retrato observa solo la cabecera y libera el observador al reaplicar', async () => {
  const context = environment();
  const header = {};
  let photo = {getAttribute:()=> 'blob:https://web.whatsapp.com/example'};
  const observers = [];
  const properties = new Map();
  context.document.documentElement.style.setProperty = (key,value) => properties.set(key,value);
  context.document.querySelector = selector => selector.endsWith(' img') ? photo : selector.includes('conversation-header') ? header : null;
  context.MutationObserver = class {
    constructor(callback){this.callback=callback;observers.push(this);}
    observe(target,options){this.target=target;this.options=options;this.active=true;}
    disconnect(){this.active=false;}
  };
  const source = await buildSource();
  vm.runInNewContext(source,context);
  vm.runInNewContext(source,context);
  assert.equal(observers.filter(o=>o.active).length,1);
  assert.equal(observers.at(-1).target,header);
  assert.equal(context.listeners.size,3);
  photo=null;
  observers.at(-1).callback();
  assert.equal(properties.get('--p5-contact-portrait'),'none');
});
test('reemplazar la cabecera por un contacto sin foto elimina el retrato anterior', async () => {
  const context=environment();const parent={parentElement:null};
  let header={parentElement:parent};let photo={getAttribute:()=> 'blob:first-contact'};
  const observers=[];const properties=new Map();
  context.document.documentElement.style.setProperty=(k,v)=>properties.set(k,v);
  context.document.querySelector=s=>s.endsWith(' img')?photo:s.includes('conversation-header')?header:null;
  context.MutationObserver=class {
    constructor(callback){this.callback=callback;observers.push(this);}
    observe(target,options){this.target=target;this.options=options;this.active=true;}
    disconnect(){this.active=false;}
  };
  vm.runInNewContext(await buildSource(),context);
  assert.match(properties.get('--p5-contact-portrait'),/first-contact/);
  const structure=observers.find(o=>o.target===parent);
  assert.equal(structure.options.subtree,undefined);
  header={parentElement:parent};photo=null;structure.callback();
  assert.equal(properties.get('--p5-contact-portrait'),'none');
  assert.equal(observers.filter(o=>o.active && o.target!==parent).length,1);
  photo={getAttribute:()=> 'blob:third-contact'};
  observers.find(o=>o.active&&o.target===header).callback();
  assert.match(properties.get('--p5-contact-portrait'),/third-contact/);
  header=null;photo=null;structure.callback();
  assert.equal(properties.get('--p5-contact-portrait'),'none');
  context.window.__p5DesktopCleanup();
  assert.equal(observers.filter(o=>o.active).length,0);
});

test('actualizaciones de presencia no reescriben el retrato si la foto no cambia', async () => {
  const context=environment(); const callbacks=[]; let writes=0;
  const header={}; let src='blob:same';
  context.document.querySelector=s=>s.endsWith(' img')?{getAttribute:()=>src}:s.includes('conversation-header')?header:null;
  context.document.documentElement.style.setProperty=()=>writes++;
  context.MutationObserver=class {
    constructor(callback){callbacks.push(callback);} observe(){} disconnect(){}
  };
  vm.runInNewContext(await buildSource(),context);
  for(let i=0;i<100;i++) callbacks[0]();
  assert.equal(writes,1);
  src=null; callbacks[0](); assert.equal(writes,2);
});

test('volver al foco descarta entradas pendientes sin tocar animaciones nativas', async () => {
  const context=environment(); let cancelled=0; let nativeCancelled=0;
  const entry={animationName:'p5-message-in',playState:'running',cancel(){cancelled++;}};
  context.document.getAnimations=()=>[entry,{animationName:'native-spinner',playState:'running',cancel(){nativeCancelled++;}}];
  vm.runInNewContext(await buildSource(),context);
  context.windowListeners.get('focus')();
  assert.equal(cancelled,1); assert.equal(nativeCancelled,0);
  context.document.hidden=true;
  const event={animationName:'p5-message-in',target:{getAnimations:()=>[entry]}};
  context.listeners.get('animationstart')(event);
  assert.equal(cancelled,2);
  context.document.hidden=false; context.document.hasFocus=()=>true;
  context.listeners.get('animationstart')(event);
  assert.equal(cancelled,2); // New foreground messages retain their entry effect.
  vm.runInNewContext(await buildSource(),context);
  assert.equal(context.windowListeners.size,1);
  context.window.__p5DesktopCleanup();
  assert.equal(context.listeners.size,0); assert.equal(context.windowListeners.size,0);
});
