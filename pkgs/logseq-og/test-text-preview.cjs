// node test-text-preview.cjs /path/to/packaged/js/preload.js
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const preload = process.argv[2];
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'logseq-preview-reader-'));
let apis;
const electron = {
  ipcRenderer: {on() {}, removeListener() {}, removeAllListeners() {}},
  contextBridge: {exposeInMainWorld(_name, value) { apis = value; }},
};
vm.runInNewContext(fs.readFileSync(preload,'utf8'), {
  require: id => id === 'electron' ? electron : require(id),
  process: {platform:process.platform,isMainFrame:false}, Buffer, console,
});
function fixture(name, content) {
  const file=path.join(root,name); fs.writeFileSync(file,content); return file;
}
test('preserves whitespace, Unicode and literal markup', async()=>{
  const text='  Привет 🌏\n<script>test()</script>\n\n';
  const result=await apis.readTextFilePreview(fixture('имя #1 (100%).txt',text));
  assert.equal(result.text,text); assert.equal(result.truncated,false);
});
test('empty file',async()=>{
  const result=await apis.readTextFilePreview(fixture('empty.txt',''));
  assert.equal(result.text,'');assert.equal(result.truncated,false);
});
test('bounded preview for large file',async()=>{
  const result=await apis.readTextFilePreview(fixture('large.txt','A'.repeat(1024*1024)));
  assert.equal(result.text,'A'.repeat(4000));assert.equal(result.truncated,true);
});
test('does not split UTF-8 at the read boundary',async()=>{
  const result=await apis.readTextFilePreview(fixture('unicode.txt','語'.repeat(10000)));
  assert.ok(result.text.length<4000);assert.equal(result.truncated,true);
  assert.equal(result.text,'語'.repeat(result.text.length));
});
test('missing file is reported',async()=>{
  await assert.rejects(()=>apis.readTextFilePreview(path.join(root,'missing.txt')), {code:'ENOENT'});
});
test('reads current content each time',async()=>{
  const file=fixture('changing.txt','before');
  assert.equal((await apis.readTextFilePreview(file)).text,'before');
  fs.writeFileSync(file,'after');
  assert.equal((await apis.readTextFilePreview(file)).text,'after');
});
test('local PDF bytes survive the bridge and special filenames',async()=>{
  const {pathToFileURL}=require('node:url');
  const bytes=Buffer.from([0x25,0x50,0x44,0x46,0,255,128,42]);
  const file=fixture('документ #1 (100%).pdf',bytes);
  for(const url of [pathToFileURL(file).href,pathToFileURL(file).href.replace('file:','assets:')]){
    assert.deepEqual(Buffer.from(await apis.readLocalPdf(url)),bytes);
  }
});
test('PDF bridge rejects remote URLs',async()=>{
  await assert.rejects(()=>apis.readLocalPdf('https://example.org/file.pdf'));
});
after(()=>console.log('Test files:',root));
