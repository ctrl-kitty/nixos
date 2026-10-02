// Automated test for Logseq Read Mode / Edit Mode toggle and hotkey
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { app } = require('electron');

const appPath = path.resolve(process.argv[2]);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'logseq-mode-test-'));
const graph = path.join(root, 'graph');

for (const dir of ['home', 'profile', 'graph/assets', 'graph/pages', 'graph/logseq']) {
  fs.mkdirSync(path.join(root, dir), { recursive: true });
}

app.setPath('home', path.join(root, 'home'));
app.setPath('userData', path.join(root, 'profile'));
app.setAppPath(appPath);
app.setName('Logseq Mode Tests');
app.setPath('logs', path.join(root, 'profile', 'logs'));
process.env.NODE_ENV = 'production';

fs.writeFileSync(
  path.join(graph, 'pages', 'TestPage.md'),
  '- # Test Header\n  - First bullet point with **bold** text\n  - Second bullet point\n'
);
fs.writeFileSync(path.join(graph, 'logseq', 'config.edn'), '{:preferred-format :markdown :ui/enable-tooltip? true}');

const timeout = setTimeout(() => {
  console.error('FAIL overall timeout', root);
  app.exit(1);
}, 120000);

app.on('browser-window-created', (_event, win) => {
  if (win.__modeTest) return;
  win.__modeTest = true;

  win.webContents.on('console-message', event => {
    if (event.level === 'error') console.error('RENDERER ERROR', event.message);
  });

  win.webContents.once('did-finish-load', async () => {
    const run = code => win.webContents.executeJavaScript(code, true);
    const until = async (code, ms = 15000) => {
      const end = Date.now() + ms;
      do {
        const result = await run(code);
        if (result) return result;
        await new Promise(r => setTimeout(r, 100));
      } while (Date.now() < end);
      throw Error('Timed out waiting for: ' + code);
    };

    try {
      console.log('INIT profile:', root);
      await until(`!![...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder'))`);
      await until(`typeof window.logseq?.api?.get_state_from_store === 'function' && !window.logseq.api.get_state_from_store('db/restoring?')`);
      await run(`window.__MOCKED_OPEN_DIR_PATH__=${JSON.stringify(graph)}; [...document.querySelectorAll('strong')].find(e=>e.textContent.includes('Choose a folder')).click()`);
      await until(`document.body.innerText.includes('Skip') || document.querySelector('#repo-name')?.textContent.includes('graph')`);
      await until(`window.logseq?.api?.get_current_graph()?.path === ${JSON.stringify(graph)}`, 15000);
      await run(`[...document.querySelectorAll('a')].find(e=>e.textContent.trim()==='Skip')?.click()`);
      await new Promise(r => setTimeout(r, 1500));

      // 1. Navigate to TestPage in Read Mode
      console.log('STEP 1: Navigate to TestPage (Read Mode)');
      await run(`window.location.hash='/page/testpage'`);
      await until(`[...document.querySelectorAll('h1')].some(e=>e.textContent.trim()==='TestPage')`);
      await until(`[...document.querySelectorAll('.ls-block')].length > 0`);

      const readModeHash = await run(`window.location.hash`);
      assert.equal(readModeHash, '#/page/testpage');
      console.log('PASS: Initial view is Read Mode at', readModeHash);

      // Verify that rendered markdown is shown (clean markdown view, no raw '# ' or '**' in rendered view)
      const boldText = await run(`!!document.querySelector('strong')`);
      assert.ok(boldText, 'Bold text should be rendered as strong tag in Read Mode');
      console.log('PASS: Content rendered as HTML elements in Read Mode');

      // 2. Trigger toggle to Edit Mode via page menu or shortcut
      console.log('STEP 2: Trigger toggle to Edit Mode');
      // Verify page menu has the toggle item
      await run(`document.querySelector('.toolbar-dots-btn')?.click()`);
      await until(`[...document.querySelectorAll('.menu-link')].some(e=>e.textContent.includes('Toggle edit / read mode'))`);
      console.log('PASS: Menu link \"Toggle edit / read mode\" exists in page menu');
      // Click the menu link to switch to Edit Mode
      await run(`[...document.querySelectorAll('.menu-link')].find(e=>e.textContent.includes('Toggle edit / read mode')).click()`);
      await until(`window.location.hash.includes('/file/')`, 10000);

      const editModeHash = await run(`window.location.hash`);
      console.log('PASS: Successfully transitioned to Edit Mode at', editModeHash);
      assert.match(editModeHash, /#\/file\/pages%2FTestPage\.md|#\/file\/pages\/TestPage\.md/, 'Route should point to file editor');

      // 3. Verify Edit Mode UI: CodeMirror editor with raw markdown & Read Mode button
      console.log('STEP 3: Verify Edit Mode text editor and UI controls');
      await until(`!!document.querySelector('.CodeMirror')`);
      await until(`!!document.querySelector('button[title*=\"Read Mode\"]')`);

      const cmValue = await run(`document.querySelector('.CodeMirror').CodeMirror.getValue()`);
      console.log('CodeMirror content preview:\n' + cmValue.slice(0, 120));
      assert.match(cmValue, /# Test Header/, 'Raw markdown heading symbol should be visible in Edit Mode');
      assert.match(cmValue, /\*\*bold\*\*/, 'Raw markdown bold syntax should be visible in Edit Mode');
      console.log('PASS: Edit Mode displays raw text of the md file');

      // 4. In Edit Mode, edit text in CodeMirror
      console.log('STEP 4: Modify file in CodeMirror');
      await run(`
        const cm = document.querySelector('.CodeMirror').CodeMirror;
        cm.focus();
        cm.setValue('- # Test Header Updated\\n  - New bullet from raw edit\\n');
      `);
      await new Promise(r => setTimeout(r, 500));

      // 5. Trigger toggle back to Read Mode via Read Mode button
      console.log('STEP 5: Switch back to Read Mode via Read Mode button');
      const debugInfo = await run(`({
        files: window.logseq?.api?.get_current_graph(),
        hash: window.location.hash
      })`);
      console.log('DEBUG INFO:', JSON.stringify(debugInfo));
      await run(`document.querySelector('button[title*=\"Read Mode\"]').click()`);
      await new Promise(r => setTimeout(r, 1000));
      const hashAfter = await run(`window.location.hash`);
      console.log('Hash after click:', hashAfter);
      await until(`window.location.hash.startsWith('#/page/')`, 10000);

      const backToReadHash = await run(`window.location.hash`);
      console.log('PASS: Successfully returned to Read Mode at', backToReadHash);

      // 6. Verify that changes made in Edit Mode are reflected in Read Mode
      console.log('STEP 6: Verify updated content in Read Mode');
      console.log('BODY TEXT in Step 6:\n' + (await run(`document.body.innerText`)).slice(0, 500));
      await until(`document.body.innerText.includes('New bullet from raw edit')`, 10000);
      console.log('PASS: Edits made in Edit Mode successfully synchronized to Read Mode!');

      // 7. Test hotkey toggling (Ctrl+Shift+E)
      console.log('STEP 7: Test hotkey toggling with Ctrl+Shift+E');
      // Send real Electron input events
      win.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'E', modifiers: ['control', 'shift'] });
      win.webContents.sendInputEvent({ type: 'keyUp', keyCode: 'E', modifiers: ['control', 'shift'] });
      await until(`window.location.hash.includes('/file/')`, 10000);
      console.log('PASS: Hotkey Ctrl+Shift+E switched from Read Mode to Edit Mode');

      // Now from inside Edit Mode, press Ctrl+Shift+E to toggle back to Read Mode
      win.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'E', modifiers: ['control', 'shift'] });
      win.webContents.sendInputEvent({ type: 'keyUp', keyCode: 'E', modifiers: ['control', 'shift'] });
      await until(`window.location.hash.startsWith('#/page/')`, 10000);
      console.log('PASS: Hotkey Ctrl+Shift+E switched from Edit Mode to Read Mode');

      clearTimeout(timeout);
      console.log('ALL MODE TOGGLE AND HOTKEY TESTS PASSED SUCCESSFULLY!');
      app.exit(0);
    } catch (err) {
      console.error('FAIL in test:', err);
      clearTimeout(timeout);
      app.exit(1);
    }
  });
});
require(path.join(appPath, 'electron.js'));
