// Live CSS regression check. Creates only temporary offscreen elements;
// never sends messages or saves WhatsApp preferences.
import assert from 'node:assert/strict';
import {connect} from '../cdp.mjs';
const client=await connect(Number(process.argv[2]));
try {
 const response=await client.send('Runtime.evaluate',{returnByValue:true,expression:`(() => {
  const main=document.querySelector('#main');if(!main)throw Error('Open a chat first');
  const saved=document.body.className;
  const fixture=document.createElement('div');fixture.style.cssText='position:absolute;left:-10000px;top:0;width:400px;pointer-events:none';
  fixture.innerHTML='<div data-testid="msg-container"><div class="x1g5lz36"><span class="selectable-text" id="p5-test-out">Outgoing</span><div data-testid="quoted-message" id="p5-test-quote"><span data-testid="author">Author</span><span class="selectable-text">Reply</span></div></div></div><div data-testid="msg-container"><div class="x1ew7x2d"><span class="selectable-text" id="p5-test-in">Incoming</span></div></div><div id="p5-test-hover" style="background:linear-gradient(gray,white)"><div data-testid="icon-down-context">Options</div></div>';
  main.appendChild(fixture);
  const result={};
  try {
   for(const mode of ['dark','light']) {
    document.body.classList.remove('dark','light');document.body.classList.add(mode);
    const css=selector=>getComputedStyle(fixture.querySelector(selector));
    result[mode]={out:css('#p5-test-out').color,incoming:css('#p5-test-in').color,
     quoteBackground:css('#p5-test-quote').backgroundColor,quoteText:css('#p5-test-quote .selectable-text').color,
     author:css('[data-testid=author]').color,hoverBackground:css('#p5-test-hover').backgroundColor,
     hoverImage:css('#p5-test-hover').backgroundImage,menuText:css('[data-testid=icon-down-context]').color,
     menuBackground:css('[data-testid=icon-down-context]').backgroundColor,
     baseText:getComputedStyle(document.querySelector('#app')).getPropertyValue('--WDS-content-default').trim(),
     baseSurface:getComputedStyle(document.querySelector('#app')).getPropertyValue('--WDS-surface-default').trim()};
   }
   return result;
  } finally {document.body.className=saved;fixture.remove();}
 })()`});
 if(response.exceptionDetails)throw Error(response.exceptionDetails.text);
 const {dark,light}=response.result.value;
 assert.deepEqual(light,dark,'Palette differs in light mode');
 assert.equal(dark.out,'rgb(9, 9, 9)');assert.equal(dark.incoming,'rgb(255, 255, 255)');
 assert.equal(dark.quoteBackground,'rgb(28, 27, 32)');assert.equal(dark.quoteText,'rgb(255, 255, 255)');
 assert.equal(dark.hoverImage,'none');assert.equal(dark.hoverBackground,'rgba(0, 0, 0, 0)');
 assert.equal(dark.menuText,'rgb(255, 255, 255)');assert.equal(dark.menuBackground,'rgb(9, 9, 9)');
 assert.equal(dark.baseText,'#fafafa');assert.equal(dark.baseSurface,'#090909');
 console.log('PASS: citas, mensajes, opciones y paleta iguales en modo claro y oscuro; estado original restaurado.');
} finally {client.close();}
