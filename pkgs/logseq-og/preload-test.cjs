// Observe the native boundary without launching external applications.
const { shell, ipcRenderer } = require('electron');
shell.openPath = async (filePath) => {
  ipcRenderer.send('test:file-open', filePath);
  return '';
};
require(process.env.LOGSEQ_TEST_PRELOAD);
