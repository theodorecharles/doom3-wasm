'use strict';

let persist = null;
let runtime = null;
let started = false;
let failed = false;

function post(type, text, extra) {
  self.postMessage({ type, text: text == null ? undefined : String(text), ...(extra || {}) });
}

function call(name, ...arguments_) {
  const fn = runtime && runtime[`_${name}`];
  if (typeof fn === 'function') return fn(...arguments_);
  return 0;
}

async function launch(message) {
  if (started) return;
  started = true;
  failed = false;
  const { canvas, entries = [], variant, width, height, playerName, engineArguments = [] } = message;
  const roe = variant === 'roe';
  try {
    post('status', `Loading ${roe ? 'Resurrection of Evil' : 'Doom 3'} engine…`);
    self.Module = runtime = {
      canvas,
      arguments: [
        '+set', 'fs_basepath', '/owner-data',
        '+set', 'fs_cdpath', '/owner-data',
        '+set', 'fs_savepath', '/save',
        '+set', 'fs_configpath', '/save',
        '+set', 'r_fullscreen', '0',
        '+set', 'r_mode', '-1',
        '+set', 'r_customWidth', String(width || 1280),
        '+set', 'r_customHeight', String(height || 720),
        '+set', 'ui_name', String(playerName || 'Marine').slice(0, 32),
        ...engineArguments,
        ...(roe ? ['+set', 'fs_game', 'd3xp'] : [])
      ],
      locateFile: path => new URL(path.endsWith('.wasm') ? `dhewm3-${roe ? 'roe' : 'base'}.wasm` : path, self.location.href).href,
      preRun: [() => {
        FS.mkdir('/owner-data');
        FS.mount(WORKERFS, { blobs: entries.map(entry => ({ name: entry.path, data: entry.file })) }, '/owner-data');
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
        post('status', 'Initializing the Doom 3 renderer and menus…');
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
      onExit: status => {
        if (status !== 0) {
          failed = true;
          post('error', `Doom 3 exited during initialization (status ${status}).`);
        }
      },
      onAbort: reason => {
        failed = true;
        post('error', reason);
      }
    };
    importScripts(`/dhewm3-${roe ? 'roe' : 'base'}.js`);
  } catch (reason) {
    started = false;
    failed = true;
    post('error', reason instanceof Error ? reason.stack || reason.message : reason);
  }
}

self.onerror = event => {
  failed = true;
  const location = event.filename ? ` (${event.filename}:${event.lineno || 0}:${event.colno || 0})` : '';
  post('error', `${event.message || 'Uncaught worker error'}${location}`);
  return true;
};

self.onmessage = event => {
  const message = event.data || {};
  if (message.type === 'start') { void launch(message); return; }
  if (message.type === 'persist') { persist?.(); return; }
  if (!runtime || failed) return;
  if (message.type === 'resize') call('D3WASM_BrowserResize', message.width | 0, message.height | 0);
  if (message.type === 'open-menu') call('D3WASM_BrowserOpenMenu');
  if (message.type === 'capture') call('D3WASM_BrowserCapture', message.captured ? 1 : 0);
  if (message.type === 'pointer-absolute') call('D3WASM_BrowserPointer', message.x | 0, message.y | 0, 0);
  if (message.type === 'pointer-relative') call('D3WASM_BrowserPointer', message.dx | 0, message.dy | 0, 1);
  if (message.type === 'pointer-button') call('D3WASM_BrowserPointerButton', message.button | 0, message.down ? 1 : 0);
  if (message.type === 'key') call('D3WASM_BrowserKey', message.scan | 0, message.key | 0, message.down ? 1 : 0, message.repeat ? 1 : 0);
  if (message.type === 'text') call('D3WASM_BrowserText', message.codepoint | 0);
};
