'use strict';
const editor = document.getElementById('editor');
const converter = new TurndownService({headingStyle:'atx', codeBlockStyle:'fenced', bulletListMarker:'-', emDelimiter:'*'});
converter.use(turndownPluginGfm.gfm);
converter.addRule('rawInline', {filter:node=>node.nodeName==='CODE' && node.hasAttribute('data-raw-inline'),replacement:(_,node)=>node.textContent});
converter.addRule('doubleStrike', {filter:['del','s','strike'], replacement: content => '~~'+content+'~~'});
converter.addRule('taskCheckbox', {
  filter: node => node.nodeName === 'INPUT' && node.type === 'checkbox',
  replacement: (_, node) => node.checked ? '[x] ' : '[ ] '
});
converter.addRule('taskItem', {
  filter:node=>node.nodeName==='LI' && !!(node.querySelector(':scope > input[type=checkbox]') || node.querySelector(':scope > p > input[type=checkbox]')),
  replacement:content=>'- '+content.trim().replace(/^(\[[ xX]\])\s+/,'$1 ').replace(/\n/g,'\n    ')+'\n'
});
converter.addRule('safeCodeFence', {
  filter: node => node.nodeName === 'PRE' && node.firstChild && node.firstChild.nodeName === 'CODE',
  replacement: (_, node) => {
    const code=node.firstChild, text=code.textContent.replace(/\n$/, '');
    const runs=text.match(/`+/g)||[];
    const fence='`'.repeat(Math.max(3,...runs.map(s=>s.length+1)));
    const language=(code.className.match(/language-(\S+)/)||[])[1]||'';
    return '\n\n'+fence+language+'\n'+text+'\n'+fence+'\n\n';
  }
});
converter.addRule('relativeImage', {filter:'img', replacement:(_,node)=>{
  const src=node.dataset.relativeSrc || node.getAttribute('src') || '';
  const alt=(node.getAttribute('alt')||'').replace(/\[/g,'\\[').replace(/\]/g,'\\]');
  const title=node.getAttribute('title');
  return '!['+alt+']('+src.replace(/ /g,'%20')+(title?' \"'+title.replace(/\"/g,'\\\"')+'\"':'')+')';
}});
// Footnote-referentie: <sup class="footnote-ref"><a id="fnref-1">1</a></sup> → [^1]
converter.addRule('footnoteRef', {filter:node=>node.nodeName==='SUP' && node.classList && node.classList.contains('footnote-ref'), replacement:(_,node)=>{
  const a=node.querySelector('a');
  const id=a ? a.id.replace(/^fnref-/,'') : node.textContent;
  return '[^'+id+']';
}});
// Highlight ==...== → <mark> (wordt door tagfilter toegelaten als bekende tag? nee —
// we renderen het zelf via Swift-preprocess, dus hier alleen de terug-conversie).
converter.addRule('mark', {filter:'mark', replacement:content=>'=='+content+'=='});
converter.addRule('underline', {filter:'u', replacement:content=>'<u>'+content+'</u>'});
// Gerenderde math-span (KaTeX of fallback) → oorspronkelijke notatie bij serialize.
converter.addRule('mathRendered', {filter:node=>node.nodeType===1 && node.hasAttribute && node.hasAttribute('katex-src') && node.classList && (node.classList.contains('math-rendered')||node.classList.contains('math-fallback')), replacement:(_,node)=>{
  const src=node.getAttribute('katex-src')||'';
  const display=node.getAttribute('data-math-display')==='true';
  return display ? '$$'+src+'$$' : '$'+src+'$';
}});
// Math-sentinel (van Swift-preprocess) → oorspronkelijke notatie, zodat de
// math-bron behouden blijft bij rich edits. Sentinelvorm: ⌘M0<base64>⌘M0 (inline)
// of ⌘M1<base64>⌘M1 (display). base64 wordt naar de formule gede decodeerd.
converter.addRule('mathSentinel', {filter:node=>node.nodeType===3 && /⌘M[01][A-Za-z0-9+/=]+⌘M[01]/.test(node.nodeValue||''), replacement:(_,node)=>{
  const m=(node.nodeValue||'').match(/⌘M([01])([A-Za-z0-9+/=]+)⌘M\1/);
  if(!m) return node.nodeValue||'';
  const display=m[1]==='1';
  const src=atob(m[2]);
  return display ? '$$'+src+'$$' : '$'+src+'$';
}});
function b64decode(s){ try { return atob(s); } catch(e){ return s; } }
function renderMath(root) {
  if(!root) return;
  // Vind sentinel-textnodes en vervang ze door KaTeX-HTML (of plain fallback).
  const walker=document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const found=[];
  let n;
  while(n=walker.nextNode()) { if(/⌘M[01][A-Za-z0-9+/=]+⌘M[01]/.test(n.nodeValue||'')) found.push(n); }
  for(const textNode of found) {
    const html=textNode.nodeValue.replace(/⌘M([01])([A-Za-z0-9+/=]+)⌘M\1/g, (_,disp,b64)=>{
      const src=b64decode(b64); const display=disp==='1';
      const srcAttr=src.replace(/"/g,'&quot;');
      if(window.katex) {
        try {
          const khtml=window.katex.renderToString(src,{displayMode:display,throwOnError:false,output:'html'});
          return '<span class="math-rendered" katex-src="'+srcAttr+'" data-math-display="'+display+'">'+khtml+'</span>';
        } catch(e){}
      }
      // Fallback (KaTeX afwezig/fout): toon de formule leesbaar, bron bewaard.
      const inner=(display?'$$':'$')+src.replace(/</g,'&lt;')+(display?'$$':'$');
      return '<span class="math-fallback" katex-src="'+srcAttr+'" data-math-display="'+display+'">'+inner+'</span>';
    });
    const span=document.createElement('span'); span.innerHTML=html;
    while(span.firstChild) textNode.parentNode.insertBefore(span.firstChild, textNode);
    textNode.parentNode.removeChild(textNode);
  }
}
let originals = new Map(), references='', lastSent='', revision=0, pendingRemote=null;
let originalHTML='', originalMarkdown='';
let frontMatterSource='';
let composing=false;
function serialize() {
  if(editor.innerHTML===originalHTML) return originalMarkdown;
  const pieces=[];
  for (const node of editor.childNodes) {
    if (node.nodeType===Node.TEXT_NODE && !node.textContent.trim()) continue;
    const saved = node.nodeType===Node.ELEMENT_NODE && originals.get(node.dataset.block);
    if (saved && node.innerHTML===saved.html) pieces.push(saved.source.replace(/\n+$/,''));
    else {
      const value=converter.turndown(node.nodeType===Node.TEXT_NODE ? node.textContent : node.outerHTML);
      if(value.trim()) pieces.push(value);
    }
  }
  if(references && pieces.length) pieces.push(references);
  let body=pieces.join('\n\n')+(pieces.length?'\n':'');
  // Een Jekyll-voorbeeld heeft een lege regel tussen de afsluiting en de body; dat
  // behouden we exact wanneer de bron dat had (frontMatter.source eindigt op "---\n").
  const hadTrailingBlank=frontMatterSource && body && frontMatterSource.endsWith('\n---\n');
  const base=frontMatterSource ? frontMatterSource.replace(/\n+$/,'') : '';
  if(base && body) return base + '\n' + (hadTrailingBlank ? '\n' : '') + body;
  return body;
}
function sendChange() {
  if(composing) return;
  const markdown=serialize();
  if(markdown===lastSent) return;
  lastSent=markdown;
  window.webkit?.messageHandlers.changed.postMessage({markdown,revision});
}
function setContent(payload, nextRevision, originalSource, folder='') {
  if(composing) {pendingRemote=[payload,nextRevision,originalSource]; return;}
  const oldScroll=window.scrollY;
  originals=new Map(); references=payload.references; revision=nextRevision;
  frontMatterSource=payload.frontMatter ? payload.frontMatter.source : '';
  editor.replaceChildren();
  for(const block of payload.blocks) {
    const section=document.createElement('section'); section.dataset.block=String(block.id);
    section.innerHTML=block.html;
    for(const input of section.querySelectorAll('input[type=checkbox]')) input.disabled=false;
    for(const image of section.querySelectorAll('img')) {
      const src=image.getAttribute('src');
      if(folder && src && !/^[a-z][a-z0-9+.-]*:/i.test(src)) {image.dataset.relativeSrc=src;image.src=new URL(src,folder).href;}
    }
    originals.set(String(block.id),{html:section.innerHTML,source:block.source});
    editor.append(section);
  }
  // Wiskunde renderen met KaTeX (na highlight, vóór originals-friegen).
  renderMath(editor);
  // Highlight codeblokken: hljs vervangt <code> door <code class="hljs language-x"> + spans.
  // De tekstcontent en de taalnaam blijven intact, dus de rich-edit roundtrip
  // (safeCodeFence-regel die op textContent + className leest) wordt niet aangetast.
  if(window.hljs) {
    for(const code of editor.querySelectorAll('pre > code')) {
      const cls=(code.className||'').match(/language-(\S+)/);
      const lang=cls ? cls[1] : '';
      // hljs.highlightElement herkent onbekende talen zelf en laat de tekst dan intact
      // (plain-code fallback), dus één call dekt zowel bekende als onbekende talen.
      try { window.hljs.highlightElement(code); } catch(e) { /* plain fallback */ }
    }
    // originals nu de ECHTE (ge-highlightte) HTML bewaart, zodat unchanged-block detectie klopt.
    for(const section of editor.children) {
      const id=section.dataset.block;
      if(originals.has(id)) originals.get(id).html=section.innerHTML;
    }
  }
  if(!editor.children.length) editor.innerHTML='<p><br></p>';
  lastSent=originalSource;originalMarkdown=originalSource;originalHTML=editor.innerHTML;
  window.scrollTo(0,oldScroll);
}
function setBasePath(folder) {
  if(!folder) return;
  const pristine=editor.innerHTML===originalHTML;
  for(const section of editor.children) {
    const saved=originals.get(section.dataset.block);
    const unchanged=saved && section.innerHTML===saved.html;
    for(const image of section.querySelectorAll('img')) {
      const src=image.dataset.relativeSrc || image.getAttribute('src');
      if(src && !/^[a-z][a-z0-9+.-]*:/i.test(src)) {image.dataset.relativeSrc=src;image.src=new URL(src,folder).href;}
    }
    if(unchanged) saved.html=section.innerHTML;
  }
  if(pristine) originalHTML=editor.innerHTML;
}
function format(command, value) {
  editor.focus();
  document.execCommand(command,false,value||null);
  sendChange();
}
editor.addEventListener('input',sendChange);
editor.addEventListener('compositionstart',()=>{composing=true;});
editor.addEventListener('compositionend',()=>{composing=false;sendChange();pendingRemote=null;});
editor.addEventListener('change',event=>{
  if(event.target.type==='checkbox') {
    event.target.toggleAttribute('checked',event.target.checked);
    sendChange();
  }
});
editor.addEventListener('paste',event=>{
  event.preventDefault();
  document.execCommand('insertText',false,event.clipboardData.getData('text/plain'));
  sendChange();
});
editor.addEventListener('keydown',event=>{
  if(event.metaKey && !event.shiftKey && ['b','i'].includes(event.key.toLowerCase())) {
    event.preventDefault();format(event.key.toLowerCase()==='b'?'bold':'italic');
  }
  if(event.metaKey && event.key.toLowerCase()==='z') {
    event.preventDefault();document.execCommand(event.shiftKey?'redo':'undo');sendChange();
  }
});
document.addEventListener('click',event=>{
  const link=event.target.closest('a');
  if(link) {event.preventDefault();if(event.metaKey) window.webkit?.messageHandlers.openLink.postMessage(link.getAttribute('href'));}
});
window.addEventListener('error',event=>window.webkit?.messageHandlers.error.postMessage(event.message));
window.markeer={setContent,setBasePath,serialize,format,editor};
document.execCommand('defaultParagraphSeparator',false,'p');
window.webkit?.messageHandlers.ready.postMessage('ready');
