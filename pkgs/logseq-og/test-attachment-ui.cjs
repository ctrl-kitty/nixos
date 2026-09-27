// Launch the actual packaged Logseq with a disposable home, profile and graph.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { app } = require('electron');
const appPath = path.resolve(process.argv[2]);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'logseq-attachment-ui-'));
const graph = path.join(root, 'graph');
for (const dir of ['home', 'profile', 'graph/assets', 'graph/pages', 'graph/logseq']) fs.mkdirSync(path.join(root,dir), {recursive:true});
app.setPath('home', path.join(root, 'home'));
app.setPath('userData', path.join(root, 'profile'));
app.setAppPath(appPath);
app.setName('Logseq Attachment Tests');
app.setPath('logs',path.join(root,'profile','logs'));
process.env.NODE_ENV = 'production';
const filename = 'пример_#1_(100%).txt';
const content = '  First preview line\n<script>window.previewExecuted = true</script>\n' + 'Long text line\n'.repeat(900) + '  END OF ATTACHMENT\n';
fs.writeFileSync(path.join(graph,'assets',filename),content);
fs.writeFileSync(path.join(graph,'assets','empty.txt'),'');
fs.writeFileSync(path.join(graph,'assets','other.zip'),'unsupported attachment');
// A tiny valid PDF, sufficient to verify that the built-in viewer loads a page.
const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>', '<< /Length 0 >>\nstream\n\nendstream'];
let pdf = '%PDF-1.4\n', offsets = [0];
objects.forEach((o,i) => { offsets.push(Buffer.byteLength(pdf)); pdf += `${i+1} 0 obj\n${o}\nendobj\n`; });
const xref = Buffer.byteLength(pdf);
pdf += `xref\n0 5\n0000000000 65535 f \n` + offsets.slice(1).map(o=>`${String(o).padStart(10,'0')} 00000 n \n`).join('') + `trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
fs.writeFileSync(path.join(graph,'assets','report_#1_(100%)_1790531914663_0.pdf'),pdf);
fs.writeFileSync(path.join(graph,'pages','Attachments.md'), [
  `- [Text attachment](../assets/${filename})`,
  '- [Empty attachment](../assets/empty.txt)',
  '- [Missing attachment](../assets/missing.txt)',
  '- [PDF attachment](../assets/report_#1_(100%)_1790531914663_0.pdf)',
  '- [ZIP attachment](../assets/other.zip)',
  '- [[Existing page]]',
  '- [Web link](https://example.org/)',
].join('\n'));
fs.writeFileSync(path.join(graph,'pages','Existing page.md'),'- Existing page content\n');
fs.writeFileSync(path.join(graph,'logseq','config.edn'),'{:preferred-format :markdown :ui/enable-tooltip? true}');
const timeout=setTimeout(()=>{console.error('FAIL overall timeout',root);app.exit(1)},60000);
app.on('browser-window-created', (_event, win) => {
  if (win.__attachmentTest) return;
  win.__attachmentTest=true;
  win.webContents.on('console-message',event=>{if(event.level==='error')console.error('RENDERER',event.message)});
  win.webContents.once('did-finish-load', async()=>{
    const run=(code)=>win.webContents.executeJavaScript(code,true);
    const until=async(code,ms=12000)=>{
      const end=Date.now()+ms;
      do {const result=await run(code);if(result)return result;await new Promise(r=>setTimeout(r,100));}while(Date.now()<end);
      throw Error('Timed out: '+code);
    };
    try {
      console.log('PROFILE',root);
      await until(`!![...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder'))`);
      await run(`window.__MOCKED_OPEN_DIR_PATH__=${JSON.stringify(graph)}; [...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder')).click()`);
      await until(`document.body.innerText.includes('Skip') || document.querySelector('#repo-name')?.textContent.includes('graph')`);
      await run(`[...document.querySelectorAll('a')].find(e=>e.textContent.trim()==='Skip')?.click()`);
      await new Promise(r=>setTimeout(r,1500));
      await run(`window.location.hash='/page/attachments'`);
      await until(`!![...document.querySelectorAll('a')].find(e=>e.textContent==='Text attachment')`);
      const info = await run(`[...document.querySelectorAll('a')].filter(e=>e.textContent.endsWith('attachment')).map(e=>({text:e.textContent,href:e.getAttribute('href'),class:e.className}))`);
      console.log('LINKS',JSON.stringify(info));
      const text=info.find(e=>e.text==='Text attachment');
      assert.match(text.href,/#\/file\//,'TXT should link to Logseq file viewer');
      assert.ok(info.find(e=>e.text==='PDF attachment').class.includes('is-pdf'),'PDF should use built-in viewer');
      let previewShown = false;
      const hover=async(label)=>{
        // Remount between cases: do not depend on the user's physical cursor
        // or on Tippy's interactive mouseleave heuristics.
        if (previewShown) {
          await run(`window.location.hash='/page/existing%20page'`);
          await until(`document.body.innerText.includes('Existing page content')`);
          await run(`window.location.hash='/page/attachments'`);
          await until(`!![...document.querySelectorAll('a')].find(e=>e.textContent==='Text attachment')`);
        }
        await new Promise(r=>setTimeout(r,1200));
        await run(`[...document.querySelectorAll('a')].find(e=>e.textContent===${JSON.stringify(label)}).closest('[data-tooltipped]').dispatchEvent(new MouseEvent('mouseenter'))`);
        previewShown = true;
      };
      await hover('Text attachment');
      await until(`!!document.querySelector('.text-file-preview pre')`);
      const preview=await run(`({text:document.querySelector('.text-file-preview pre').textContent,executed:!!window.previewExecuted,html:!!document.querySelector('.text-file-preview script')})`);
      assert.ok(preview.text.startsWith('  First preview line\n<script>'));
      assert.ok(preview.text.length<=4000 && !preview.text.includes('END OF ATTACHMENT'));
      assert.equal(preview.executed,false);assert.equal(preview.html,false);
      await new Promise(r=>setTimeout(r,500));
      fs.writeFileSync(path.join(root,'preview.png'),(await win.webContents.capturePage()).toPNG());
      await hover('Empty attachment');
      await until(`document.querySelector('.text-file-preview')?.textContent.includes('Empty file')`);
      await hover('Missing attachment');
      await until(`document.querySelector('.text-file-preview')?.textContent.includes('Unable to read this file.')`);
      console.log('PASS empty and missing file previews');
      win.webContents.sendInputEvent({type:'mouseMove',x:20,y:20});
      await run(`[...document.querySelectorAll('a')].find(e=>e.textContent==='Text attachment').click()`);
      await until(`!!document.querySelector('.CodeMirror')`);
      const value=await run(`document.querySelector('.CodeMirror').CodeMirror.getValue()`);
      assert.ok(value.includes('END OF ATTACHMENT'),'Full file should be available');
      console.log('PASS hover preview and full text viewer');
      fs.writeFileSync(path.join(root,'text-viewer.png'),(await win.webContents.capturePage()).toPNG());
      await run(`window.location.hash='/page/attachments'`);
      await until(`!![...document.querySelectorAll('a')].find(e=>e.textContent==='PDF attachment')`);
      await run(`[...document.querySelectorAll('a')].find(e=>e.textContent==='PDF attachment').click()`);
      await until(`!!document.querySelector('.pdfViewer .page canvas')`,20000);
      fs.writeFileSync(path.join(root,'pdf-viewer.png'),(await win.webContents.capturePage()).toPNG());
      assert.equal(fs.readFileSync(path.join(graph,'assets',filename),'utf8'),content,'Preview/open must not rewrite the attachment');
      console.log('PASS internal PDF viewer');
      console.log('PASS packaged attachment UI',root);
      clearTimeout(timeout);app.exit(0);
    } catch(error) {
      console.error('FAIL',error);
      console.error('BODY',await run('document.body.innerText.slice(0,2000)').catch(()=>''));
      fs.writeFileSync(path.join(root,'failure.png'),(await win.webContents.capturePage()).toPNG());
      clearTimeout(timeout);app.exit(1);
    }
  });
});
require(path.join(appPath,'electron.js'));
