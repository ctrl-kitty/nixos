// Run with Electron: test-file-links.cjs /path/to/resources/app/js/preload.js
// Uses the shipped preload in a real, isolated Chromium renderer.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { app, BrowserWindow, protocol, ipcMain } = require('electron');
process.env.LOGSEQ_TEST_PRELOAD = path.resolve(process.argv[2]);
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'logseq-file-links-test-'));
app.setPath('userData', profile);
protocol.registerSchemesAsPrivileged([{ scheme: 'lsp', privileges: {
  standard: true, secure: true, supportFetchAPI: true, corsEnabled: true,
} }]);
const opened = [];
ipcMain.on('test:file-open', (_event, filePath) => opened.push(filePath));
const timeout = setTimeout(() => { console.error('FAIL: test timeout'); app.exit(1); }, 20000);
app.whenReady().then(async () => {
  protocol.handle('lsp', () => new Response('<!doctype html><body></body>', {
    headers: { 'content-type': 'text/html' },
  }));
  const win = new BrowserWindow({ show: false, webPreferences: {
    preload: path.join(__dirname, 'preload-test.cjs'),
    sandbox: false, contextIsolation: true, webSecurity: true,
  } });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  const blocked = [];
  win.webContents.on('console-message', (event) => {
    if (event.message?.includes('Not allowed to load local resource')) blocked.push(event.message);
  });
  await win.loadURL('lsp://logseq.com/electron.html');
  async function click({ href, raw, nested = false, type = 'click', cancel = false }) {
    const count = opened.length;
    const result = await win.webContents.executeJavaScript(`(() => {
      const a = document.createElement('a');
      a.href = ${JSON.stringify(href)}; a.target = '_blank';
      ${raw === undefined ? '' : `a.setAttribute('data-href', ${JSON.stringify(raw)});`}
      a.innerHTML = ${JSON.stringify(nested ? '<strong>attachment</strong>' : 'attachment')};
      document.body.appendChild(a);
      ${cancel ? "window.addEventListener('click', e => e.preventDefault(), {capture:true, once:true});" : ''}
      const event = new MouseEvent(${JSON.stringify(type)}, {bubbles:true, cancelable:true, button:${type === 'auxclick' ? 1 : 0}});
      (a.firstElementChild || a).dispatchEvent(event);
      a.remove();
      return {prevented:event.defaultPrevented};
    })()`, true);
    await new Promise(r => setTimeout(r, 100));
    return { ...result, paths: opened.slice(count) };
  }
  const failures = [];
  async function check(name, args, expected) {
    try { assert.deepEqual((await click(args)).paths, expected); console.log('PASS', name); }
    catch (e) { failures.push(name); console.error('FAIL', name, e.message); }
  }
  for (const file of ['plain.txt', 'report (2).pdf', 'Antigravity_#1_(2).txt', 'заметка 100% #1.txt']) {
    const raw = path.join(profile, file);
    fs.writeFileSync(raw, 'test attachment');
    await check(file, {href: 'file://' + raw, raw, nested: true}, [raw]);
  }
  const encodedPath = path.join(profile, 'encoded #1 100%.txt');
  await check('encoded file URL', {href:pathToFileURL(encodedPath).href}, [encodedPath]);
  await check('middle click', {href:pathToFileURL(encodedPath).href, type:'auxclick'}, [encodedPath]);
  await check('cancelled click', {href:pathToFileURL(encodedPath).href, cancel:true}, []);
  await check('page reference', {href:'#/page/existing'}, []);
  await check('web URL', {href:'https://example.org/file.txt'}, []);
  await check('embedded PDF', {href:'assets:///tmp/report.pdf'}, []);
  await win.loadURL('lsp://logseq.io/plugins/test/index.html');
  await check('plugin document is untouched', {href:pathToFileURL(encodedPath).href}, []);
  console.log(JSON.stringify({failures, chromiumBlocked:blocked.length, profile}));
  clearTimeout(timeout);
  app.exit(failures.length ? 1 : 0);
}).catch(error => { console.error(error); app.exit(1); });
