const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const resources=path.resolve(__dirname,'../Resources');
const dom=new JSDOM('<article id="editor" contenteditable="true"></article>',{runScripts:'outside-only',url:'file://'+resources+'/editor.html'});
const {window}=dom;
window.scrollTo=()=>{};window.document.execCommand=()=>true;
const messages=[];
window.webkit={messageHandlers:{changed:{postMessage:x=>messages.push(x)},ready:{postMessage:()=>{}},error:{postMessage:x=>{throw Error(x)}},openLink:{postMessage:()=>{}}}};
// atob polyfill voor JSDOM (base64-decoding voor math-sentinel) + KaTeX laden.
window.atob=(s)=>Buffer.from(s,'base64').toString('binary');
for(const name of ['turndown.js','turndown-plugin-gfm.js','highlight.min.js','katex.min.js','editor.js']) window.eval(fs.readFileSync(path.join(resources,name),'utf8'));
const source=fs.readFileSync(process.argv[2],'utf8'),payload=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));
let count=0;
function test(name,fn){fn();count++;console.log('PASS '+name);}
const {markeer,document}=window;
markeer.setContent(payload,5,source);
test('unchanged blocks preserve Markdown',()=>assert.equal(markeer.serialize(),source));
document.querySelector('h1').textContent='Gewijzigd';
test('rich heading edit becomes Markdown',()=>assert.ok(markeer.serialize().startsWith('# Gewijzigd\n')));
test('untouched table stays byte for byte',()=>assert.ok(markeer.serialize().includes('| één | twee |')));
test('untouched code keeps language',()=>assert.ok(markeer.serialize().includes('```swift\nlet x = 1\n```')));
document.querySelector('tbody td').textContent='drie';
test('table cell edit keeps GFM structure',()=>assert.match(markeer.serialize(),/\| drie \| twee \|/));
const checkbox=document.querySelector('input');checkbox.checked=false;checkbox.removeAttribute('checked');
test('checkbox edit retains task list',()=>assert.match(markeer.serialize(),/- \[ \] Klaar/));
markeer.editor.innerHTML='<p>A <strong>bold</strong> and <em>italic</em> <a href="https://example.com">link</a>.</p>';
test('new rich formatting converts',()=>assert.equal(markeer.serialize(),'A **bold** and *italic* [link](https://example.com).\n'));
markeer.editor.innerHTML='<pre><code class="language-md">```inside```</code></pre>';
test('code containing backticks uses longer fence',()=>assert.equal(markeer.serialize(),'````md\n```inside```\n````\n'));
markeer.editor.innerHTML='<p><br></p>';
test('clear document',()=>assert.equal(markeer.serialize(),''));
markeer.setContent({blocks:[{id:0,html:'<p><a href="https://example.com">site</a></p>',source:'[site][s]'}],references:'[s]: https://example.com'},6,'[site][s]\n\n[s]: https://example.com\n');
test('reference-style links retained',()=>assert.equal(markeer.serialize(),'[site][s]\n\n[s]: https://example.com\n'));
markeer.editor.innerHTML='<p><br></p>';
test('clear reference document',()=>assert.equal(markeer.serialize(),''));
markeer.setContent({blocks:[{id:0,html:'<p><img src="images/café.png" alt="Test"> Caption</p>',source:'![Test](images/café.png) Caption'}],references:''},7,'![Test](images/café.png) Caption\n','file:///Users/example/notes/');
test('relative image resolves locally',()=>assert.equal(document.querySelector('img').src,'file:///Users/example/notes/images/caf%C3%A9.png'));
document.querySelector('p').append(' edited');
test('editing image paragraph retains relative path',()=>assert.ok(markeer.serialize().includes('![Test](images/café.png)')));
markeer.editor.dispatchEvent(new window.Event('input'));
test('edits reach native bridge with revision',()=>{assert.equal(messages.at(-1).revision,7);assert.ok(messages.at(-1).markdown.includes('edited'));});
test('no duplicate change event',()=>{const n=messages.length;markeer.editor.dispatchEvent(new window.Event('input'));assert.equal(messages.length,n);});
markeer.editor.innerHTML='<p>Text <code data-raw-inline="true">&lt;span&gt;</code>edited<code data-raw-inline="true">&lt;/span&gt;</code></p>';
test('inline HTML survives rich editing safely',()=>assert.equal(markeer.serialize(),'Text <span>edited</span>\n'));
markeer.setContent({blocks:[{id:0,html:'<p><img src="images/test.png"> Caption</p>',source:'![](images/test.png) Caption'}],references:''},8,'![](images/test.png) Caption\n','file:///old/');
const savedNode=markeer.editor.firstElementChild;
test('save location updates preserve editor DOM and Markdown',()=>{markeer.setBasePath('file:///new/');assert.equal(markeer.editor.firstElementChild,savedNode);assert.equal(document.querySelector('img').src,'file:///new/images/test.png');assert.equal(markeer.serialize(),'![](images/test.png) Caption\n');});
markeer.setContent({blocks:[],references:''},9,'');markeer.editor.innerHTML='<ol start="3"><li>Eerste</li><li>Tweede</li></ol>';
test('numbered list converts with correct starting number',()=>{assert.match(markeer.serialize(),/^3\.\s+Eerste\n4\.\s+Tweede\n$/);});

// Front-matter (Jekyll): exact behouden bij body-editing; afwezig als bron het niet heeft.
const fmSource='---\ntitle: Café 🌱\ndate: 2026-11-22\ntags: [test, ünicode]\ndraft: true\n---\n\n# Kop\n\nTekst.\n';
const fmMatter={source:'---\ntitle: Café 🌱\ndate: 2026-11-22\ntags: [test, ünicode]\ndraft: true\n---'};
markeer.setContent({blocks:[{id:0,html:'<h1>Kop</h1>',source:'# Kop'},{id:1,html:'<p>Tekst.</p>',source:'Tekst.'}],references:'',frontMatter:fmMatter},10,fmSource);
test('front-matter exact behouden bij ongewijzigd document',()=>assert.equal(markeer.serialize(),fmSource));
document.querySelector('h1').textContent='Gewijzigd';
test('front-matter behouden bij kop-edit',()=>{const out=markeer.serialize();assert.ok(out.startsWith('---\ntitle: Café 🌱\n'));assert.ok(out.includes('# Gewijzigd'));assert.ok(out.includes('Tekst.'));});
document.querySelector('p').textContent='Aangepast';
test('front-matter + beide body-blokken',()=>{const out=markeer.serialize();assert.ok(out.startsWith('---\ntitle:'));assert.ok(out.includes('# Gewijzigd'));assert.ok(out.endsWith('Aangepast\n'));assert.ok(!out.includes('\n\n\n'));});
markeer.setContent({blocks:[{id:0,html:'<p>Plain</p>',source:'Plain'}],references:''},11,'Plain\n');
test('geen front-matter → geen prepend',()=>assert.equal(markeer.serialize(),'Plain\n'));
markeer.editor.innerHTML='<p><br></p>';
test('clear document na front-matter',()=>assert.equal(markeer.serialize(),''));


// Syntaxhighlighting (highlight.js): spans toegevoegd, code + taalnaam ongewijzigd bij roundtrip.
const hlSource='```swift\nlet x = 1\n```\n';
markeer.setContent({blocks:[{id:0,html:'<pre><code class="language-swift">let x = 1</code></pre>',source:'```swift\nlet x = 1\n```'}],references:''},12,hlSource);
test('codeblok krijgt highlight spans',()=>{const code=document.querySelector('pre > code');assert.ok(code && (code.innerHTML.includes('<span')||code.innerHTML.includes('class="hljs')), 'geen spans');});
test('highlight behoudt code-tekst en taal bij ongewijzigd blok',()=>assert.equal(markeer.serialize(),'```swift\nlet x = 1\n```\n'));
document.querySelector('pre > code').textContent='let y = 2';
test('edit binnen ge-highlight block roundtrippet naar Markdown',()=>assert.equal(markeer.serialize(),'```swift\nlet y = 2\n```\n'));
const unknownSource='```notaal\nxyz\n```\n';
markeer.setContent({blocks:[{id:0,html:'<pre><code class="language-notaal">xyz</code></pre>',source:'```notaal\nxyz\n```'}],references:''},13,unknownSource);
test('onbekende taal valt terug op plain code (tekst ongewijzigd)',()=>{const code=document.querySelector('pre > code');assert.equal(code.textContent,'xyz');});
test('onbekende taal roundtrippet exact',()=>assert.equal(markeer.serialize(),'```notaal\nxyz\n```\n'));
const noLangSource='```\nplain\n```\n';
markeer.setContent({blocks:[{id:0,html:'<pre><code>plain</code></pre>',source:'```\nplain\n```'}],references:''},14,noLangSource);
test('codeblok zonder taal blijft plain en roundtrippet',()=>assert.equal(markeer.serialize(),'```\nplain\n```\n'));


// Footnotes: <sup class="footnote-ref"> → [^n] bij serialize.
const fnSource='Tekst met footnote.[^1]\n\n[^1]: De voetnoot.\n';
const fnPayload={blocks:[
  {id:0,html:'<p>Tekst met footnote.<sup class="footnote-ref"><a href="#fn-1" id="fnref-1">1</a></sup></p>',source:'Tekst met footnote.[^1]'},
  {id:1,html:'<section class="footnotes"><ol><li id="fn-1"><p>De voetnoot. <a href="#fnref-1" class="footnote-backref">↩</a></p></li></ol></section>',source:'[^1]: De voetnoot.'}
],references:''};
markeer.setContent(fnPayload,20,fnSource);
test('footnote-referentie convergeert naar [^n]',()=>{const out=markeer.serialize();assert.ok(out.includes('Tekst met footnote.[^1]'));});
test('footnote-definitie wordt behouden',()=>assert.ok(markeer.serialize().includes('[^1]: De voetnoot.')));
// Highlight <mark> → ==...==
const markSource='==belangrijk== tekst.\n';
markeer.setContent({blocks:[{id:0,html:'<p><mark>belangrijk</mark> tekst.</p>',source:'<mark>belangrijk</mark> tekst.'}],references:''},21,markSource);
test('mark convergeert naar ==...==',()=>assert.ok(markeer.serialize().includes('==belangrijk==')));


// Wiskunde (KaTeX, #1825): sentinel → KaTeX-HTML, en bij serialize terug naar notatie.
// De Swift-render levert sentinels (⌘M0/⌘M1 + base64) in de block-html/source.
const b64=(str)=>Buffer.from(str,'binary').toString('base64');
// Inline \(..\]
const inlineSrc='Laat ⌘M0'+b64('a^2+b^2')+'⌘M0 zien.\n';
markeer.setContent({blocks:[{id:0,html:'<p>Laat ⌘M0'+b64('a^2+b^2')+'⌘M0 zien.</p>',source:inlineSrc}],references:''},30,inlineSrc);
test('inline-math-sentinel rendert naar KaTeX-HTML',()=>{const el=markeer.editor.querySelector('.math-rendered, .math-fallback');assert.ok(el,'geen math-span');});
// Ongeedite blok → originele source (met sentinel) behouden (vereiste: source-behoud).
test('inline-math: ongeedite blok bewaart source',()=>{const out=markeer.serialize();assert.ok(out.includes('⌘M0'),'source niet behouden: '+out);});
// Edit het blok → gaat door Turndown, sentinel wordt notatie.
markeer.editor.querySelector('.math-rendered, .math-fallback').insertAdjacentText('beforebegin',' aangepast');
test('inline-math: edit → notatie in output',()=>{const out=markeer.serialize();assert.ok(out.includes('a^2+b^2'),'formule verloren: '+out);});
// Display $$..$$
const dispSrc='⌘M1'+b64('x=1')+'⌘M1\n';
markeer.setContent({blocks:[{id:0,html:'<p>⌘M1'+b64('x=1')+'⌘M1</p>',source:dispSrc}],references:''},31,dispSrc);
test('display-math: ongeedite blok bewaart source',()=>{const out=markeer.serialize();assert.ok(out.includes('⌘M1'),'source niet behouden: '+out);});
markeer.editor.querySelector('.math-rendered, .math-fallback').insertAdjacentText('beforebegin',' b');
test('display-math: edit → formule in output',()=>{const out=markeer.serialize();assert.ok(out.includes('x=1'),'formule verloren: '+out);});
// Ongebruikte formule blijft intact (geen sentinel → geen math).
const plainSrc='Gewone tekst zonder math.\n';
markeer.setContent({blocks:[{id:0,html:'<p>Gewone tekst zonder math.</p>',source:plainSrc}],references:''},32,plainSrc);
test('geen math-sentinel → geen math-span',()=>{assert.equal(markeer.editor.querySelector('.math-rendered, .math-fallback'),null);});

console.log(count+' editor checks passed');

