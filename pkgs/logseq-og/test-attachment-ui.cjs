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
// Tall pages make next-page preparation observable without scrolling.
const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R 9 0 R 11 0 R 13 0 R] /Count 6 >>'];
for(let i=0;i<6;i++){
  const stream='BT /F1 18 Tf 12 1100 Td (PDF page '+(i+1)+') Tj ET';
  objects.push('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 1200] /Resources << /Font << /F1 15 0 R >> >> /Contents '+(4+i*2)+' 0 R >>', '<< /Length '+Buffer.byteLength(stream)+' >>\nstream\n'+stream+'\nendstream');
}
objects.push('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
let pdf = '%PDF-1.4\n', offsets = [0];
objects.forEach((o,i) => { offsets.push(Buffer.byteLength(pdf)); pdf += `${i+1} 0 obj\n${o}\nendobj\n`; });
const xref = Buffer.byteLength(pdf);
pdf += `xref\n0 ${objects.length+1}\n0000000000 65535 f \n` + offsets.slice(1).map(o=>`${String(o).padStart(10,'0')} 00000 n \n`).join('') + `trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
fs.writeFileSync(path.join(graph,'assets','report_#1_(100%)_1790531914663_0.pdf'),pdf);
const markdown='# Markdown attachment\n\n**Bold preview**\n\n<script>window.markdownExecuted = true</script>\n';
fs.writeFileSync(path.join(graph,'assets','markdown.md'),markdown);
fs.writeFileSync(path.join(graph,'pages','Attachments.md'), [
  '- ![Embedded Markdown](../assets/markdown.md)',
  '- [Linked Markdown](../assets/markdown.md)',
  '- [Renamed page link](../pages/Existing page.md)',
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
const timeout=setTimeout(()=>{console.error('FAIL overall timeout',root);app.exit(1)},120000);
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
      await run(`window.addEventListener('unhandledrejection',e=>console.error('UNHANDLED STACK',e.reason?.stack || e.reason))`);
      await until(`!![...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder'))`);
      // The picker renders before async demo-graph restoration finishes.
      // Opening another graph during that restoration races its search index.
      await until(`typeof window.logseq?.api?.get_state_from_store === 'function' && !window.logseq.api.get_state_from_store('db/restoring?')`);
      await run(`window.__MOCKED_OPEN_DIR_PATH__=${JSON.stringify(graph)}; [...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder')).click()`);
      await until(`document.body.innerText.includes('Skip') || document.querySelector('#repo-name')?.textContent.includes('graph')`);
      await until(`window.logseq?.api?.get_current_graph()?.path === ${JSON.stringify(graph)}`,15000);
      await run(`[...document.querySelectorAll('a')].find(e=>e.textContent.trim()==='Skip')?.click()`);
      await new Promise(r=>setTimeout(r,1500));
      await run(`window.location.hash='/page/attachments'`);
      await until(`!![...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent==='Text attachment')`);
      const info = await run(`[...document.querySelectorAll('a')].filter(e=>e.textContent.endsWith('attachment')).map(e=>({text:e.textContent,href:e.getAttribute('href'),class:e.className}))`);
      console.log('LINKS',JSON.stringify(info));
      const text=info.find(e=>e.text==='Text attachment');
      assert.match(text.href,/#\/file\//,'TXT should link to Logseq file viewer');
      assert.ok(info.find(e=>e.text==='PDF attachment').class.includes('is-pdf'),'PDF should use built-in viewer');
      const failures=[];
      const check=async(name,fn)=>{try{await fn();console.log('PASS',name)}catch(e){failures.push(name+': '+e.message);console.error('FAIL',name,e.message);console.error('PREVIEW DOM',await run(`[...document.querySelectorAll('.tippy-popper')].map(e=>e.outerHTML.slice(0,4000))`));fs.writeFileSync(path.join(root,'case-failure.png'),(await win.webContents.capturePage()).toPNG())}};
      if (!process.argv.includes('--pdf-only')) {
        const hover=async(label)=>{
          // Remount between cases: do not depend on the user's physical cursor
          // or on Tippy's interactive mouseleave heuristics.
            await run(`window.location.hash='/page/existing%20page'`);
            await until(`[...document.querySelectorAll('h1')].some(e=>e.textContent.trim()==='Existing page')`);
            await run(`window.location.hash='/page/attachments'`);
            await until(`!![...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent==='Text attachment')`);
          await run(`[...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent===${JSON.stringify(label)}).scrollIntoView({block:'center'})`);
          await new Promise(r=>setTimeout(r,1200));
          assert.ok(await run(`!![...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent===${JSON.stringify(label)}).closest('[data-tooltipped]')`),'Link needs a hover trigger');
          await run(`[...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent===${JSON.stringify(label)}).closest('[data-tooltipped]').dispatchEvent(new MouseEvent('mouseenter'))`);
        };
        await check('wiki page hover',async()=>{
          await hover('Existing page');
          await until(`[...document.querySelectorAll('.tippy-popper .page-blocks-inner')].some(e=>e.textContent.includes('Existing page content'))`);
        });
        await check('Markdown file link resolves its target, not its label',async()=>{
          await hover('Renamed page link');
          await until(`[...document.querySelectorAll('.tippy-popper .page-blocks-inner')].some(e=>e.textContent.includes('Existing page content'))`);
        });
        for (const label of ['Embedded Markdown','Linked Markdown']) await check(label+' hover',async()=>{
          await hover(label);
          await until(`[...document.querySelectorAll('.tippy-popper .markdown-file-preview b, .tippy-popper .page-blocks-inner b')].some(e=>e.textContent === 'Bold preview')`);
          assert.equal(await run(`!!document.querySelector('.tippy-popper script') || !!window.markdownExecuted`),false);
          fs.writeFileSync(path.join(root,label.replaceAll(' ','-')+'.png'),(await win.webContents.capturePage()).toPNG());
        });
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
        await run(`[...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent==='Text attachment').click()`);
        await until(`!!document.querySelector('.CodeMirror')`);
        const value=await run(`document.querySelector('.CodeMirror').CodeMirror.getValue()`);
        assert.ok(value.includes('END OF ATTACHMENT'),'Full file should be available');
        console.log('PASS hover preview and full text viewer');
        fs.writeFileSync(path.join(root,'text-viewer.png'),(await win.webContents.capturePage()).toPNG());
      }
      await run(`window.location.hash='/page/attachments'`);
      await until(`!![...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent==='PDF attachment')`);
      await run(`[...document.querySelectorAll('#main-content-container a')].find(e=>e.textContent==='PDF attachment').click()`);
      await until(`!!document.querySelector('.pdfViewer .page canvas')`,20000);
      fs.writeFileSync(path.join(root,'pdf-viewer.png'),(await win.webContents.capturePage()).toPNG());
      assert.equal(fs.readFileSync(path.join(graph,'assets',filename),'utf8'),content,'Preview/open must not rewrite the attachment');
      console.log('PASS internal PDF viewer');
      await check('prepares two following pages before scrolling',async()=>{
        await until(`window.lsActivePdfViewer.getPageView(2).renderingState === 3`,5000);
        assert.equal(await run(`window.lsActivePdfViewer.container.scrollTop`),0);
        assert.equal(await run(`window.lsActivePdfViewer.getPageView(5).renderingState`),0,'Do not eagerly render the whole document');
        await run(`window.lsActivePdfViewer.currentPageNumber = 3`);
        await until(`window.lsActivePdfViewer.container.scrollTop > 0 && document.querySelector('.page[data-page-number="3"] .textLayer')?.textContent.includes('PDF page 3')`);
        await run(`window.lsActivePdfViewer.currentPageNumber = 1`);
      });
      const toggleTheme=async()=>{
        await run(`document.activeElement.blur()`);
        for(let i=0;i<2;i++){win.webContents.sendInputEvent({type:'keyDown',keyCode:'T'});win.webContents.sendInputEvent({type:'keyUp',keyCode:'T'});await new Promise(r=>setTimeout(r,100));}
      };
      await toggleTheme();
      await until(`document.documentElement.dataset.theme === 'dark'`);
      await check('PDF follows application dark theme',async()=>{
        await until(`document.querySelector('.extensions__pdf-container').dataset.theme === 'dark'`,3000);
      });
      fs.writeFileSync(path.join(root,'pdf-dark.png'),(await win.webContents.capturePage()).toPNG());
      await toggleTheme();
      await until(`document.documentElement.dataset.theme === 'light'`);
      await check('PDF follows application light theme',async()=>{
        await until(`document.querySelector('.extensions__pdf-container').dataset.theme === 'light'`,3000);
      });
      await run(`document.querySelector('.extensions__pdf-toolbar a[title="More settings"]').click()`);
      await until(`!!document.querySelector('.theme-picker .warm')`);
      await run(`document.querySelector('.theme-picker .warm').click()`);
      await until(`document.querySelector('.extensions__pdf-container').dataset.theme === 'warm'`);
      await check('explicit PDF theme and returning to Auto',async()=>{
        await toggleTheme();
        await until(`document.documentElement.dataset.theme === 'dark'`);
        assert.equal(await run(`document.querySelector('.extensions__pdf-container').dataset.theme`),'warm');
        await run(`document.querySelector('.theme-picker .auto').click()`);
        await until(`document.querySelector('.extensions__pdf-container').dataset.theme === 'dark'`);
      });
      console.log('GPU',JSON.stringify(app.getGPUFeatureStatus()));
      assert.equal(fs.readFileSync(path.join(graph,'assets','markdown.md'),'utf8'),markdown);
      assert.equal(failures.length,0,failures.join('\n'));
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
