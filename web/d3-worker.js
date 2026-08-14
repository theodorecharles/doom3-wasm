'use strict';

let persist = null;
self.onmessage = async event => {
  if (event.data && event.data.type === 'persist') {
    if (persist) persist();
    return;
  }
  const { canvas, entries, mode } = event.data;
  const post = (type, text) => self.postMessage({ type, text: String(text) });
  const variant = mode === 'roe' ? 'roe' : 'base';
  const scriptName = `dhewm3-${variant}.js`;
  const wasmName = `dhewm3-${variant}.wasm`;
  try {
    post('status', `Loading ${mode === 'roe' ? 'Resurrection of Evil' : 'Doom 3'} engine…`);
    self.Module = {
      canvas,
      arguments: [
        '+set', 'fs_basepath', '/owner-data',
        '+set', 'fs_cdpath', '/owner-data',
        '+set', 'fs_savepath', '/save',
        '+set', 'fs_configpath', '/save',
        '+set', 'r_fullscreen', '0',
        '+set', 'r_mode', '-1',
        '+set', 'r_customWidth', '1280',
        '+set', 'r_customHeight', '720',
        ...(mode === 'roe' ? ['+set', 'fs_game', 'd3xp'] : [])
      ],
      locateFile: path => new URL(path.endsWith('.wasm') ? wasmName : path, self.location.href).href,
      preRun: [() => {
        FS.mkdir('/owner-data');
        FS.mount(WORKERFS, {
          blobs: entries.map(entry => ({ name: entry.path, data: entry.file }))
        }, '/owner-data');
        FS.mkdir('/save');
        FS.mount(IDBFS, {}, '/save');
        addRunDependency('doom3-save-restore');
        FS.syncfs(true, error => {
          if (error) post('log', `Save restore warning: ${error}`);
          removeRunDependency('doom3-save-restore');
        });
      }],
      print: line => post('log', line),
      printErr: line => post('log', `ERR: ${line}`),
      onRuntimeInitialized: () => {
        post('status', `${mode === 'roe' ? 'Resurrection of Evil' : mode === 'mp' ? 'Doom 3 multiplayer' : 'Doom 3 single-player'} runtime initialized`);
        let syncing = false;
        persist = () => {
          if (syncing) return;
          syncing = true;
          FS.syncfs(false, error => {
            syncing = false;
            if (error) post('log', `Save persistence warning: ${error}`);
          });
        };
        setInterval(persist, 10000);
      },
      onAbort: reason => post('error', reason)
    };
    importScripts(scriptName);
  } catch (reason) {
    post('error', reason instanceof Error ? reason.stack || reason.message : reason);
  }
};
