(() => {
  'use strict';

  const profileArguments = Object.freeze({
    performance: ['+set', 'com_machineSpec', '1', '+set', 'r_multiSamples', '0', '+set', 'r_skipBump', '1'],
    high: ['+set', 'com_machineSpec', '3', '+set', 'r_multiSamples', '2', '+set', 'r_skipBump', '0'],
    ultra: ['+set', 'com_machineSpec', '3', '+set', 'image_useCompression', '0', '+set', 'image_usePrecompressedTextures', '1', '+set', 'r_multiSamples', '4']
  });
  const scancodes = Object.freeze({
    Escape: 41, Enter: 40, NumpadEnter: 88, Backspace: 42, Tab: 43, Space: 44,
    ArrowRight: 79, ArrowLeft: 80, ArrowDown: 81, ArrowUp: 82,
    ShiftLeft: 225, ShiftRight: 229, ControlLeft: 224, ControlRight: 228,
    AltLeft: 226, AltRight: 230
  });

  let worker = null;
  let ownerData = null;
  let started = false;
  let state = 'menu';
  let lastResize = null;

  function keyScan(code) {
    if (scancodes[code]) return scancodes[code];
    if (/^Key[A-Z]$/.test(code)) return code.charCodeAt(3) - 61;
    if (/^Digit[1-9]$/.test(code)) return 30 + Number(code.slice(5)) - 1;
    if (code === 'Digit0') return 39;
    return 0;
  }

  function manifestVariant(manifest, variant) {
    const selected = manifest.variants?.[variant];
    if (!selected) throw new Error(`Doom 3 data policy has no ${variant} variant.`);
    return {
      // Shared base PK4 keys intentionally use one cache namespace so changing
      // between SP, MP, and RoE never downloads identical owner data twice.
      namespace: selected.namespace || manifest.namespace,
      version: selected.version || manifest.version,
      files: selected.files
    };
  }

  function createDataSet(ctx, policy) {
    return ctx.framework.createOwnerDataSet({
      namespace: policy.namespace,
      version: policy.version,
      files: policy.files.map(spec => ({
        ...spec,
        mountName: spec.path,
        validateCached: false
      }))
    });
  }

  function viewport(ctx) {
    const detail = lastResize || {};
    return {
      width: Math.max(640, Number(detail.requestedWidth || ctx.elements.canvas.width || 1280)),
      height: Math.max(480, Number(detail.requestedHeight || ctx.elements.canvas.height || 720))
    };
  }

  function post(message) {
    if (worker) worker.postMessage(message);
  }

  function bindInput(ctx) {
    document.addEventListener('keydown', event => {
      if (!started || event.ctrlKey || event.metaKey || event.altKey) return;
      const scan = keyScan(event.code);
      if (!scan) return;
      post({ type: 'key', scan, key: event.key.length === 1 ? event.key.charCodeAt(0) : 0, down: true, repeat: event.repeat });
      if (event.key.length === 1 && !event.repeat) post({ type: 'text', codepoint: event.key.charCodeAt(0) });
      if (['Escape', 'Enter', 'Tab', 'Backspace', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' '].includes(event.key)) event.preventDefault();
    }, true);
    document.addEventListener('keyup', event => {
      if (!started) return;
      const scan = keyScan(event.code);
      if (scan) post({ type: 'key', scan, key: event.key.length === 1 ? event.key.charCodeAt(0) : 0, down: false });
    }, true);
    ctx.elements.canvas.addEventListener('pointermove', event => {
      if (document.pointerLockElement === ctx.elements.canvas) {
        post({ type: 'pointer-relative', dx: event.movementX, dy: event.movementY });
      }
    });
  }

  globalThis.WasmGameAdapter = Object.freeze({
    async init(ctx) {
      const manifest = await fetch('/wasm-game-data.json', { cache: 'no-store' }).then(response => {
        if (!response.ok) throw new Error(`Doom 3 data policy failed with HTTP ${response.status}.`);
        return response.json();
      });
      ownerData = createDataSet(ctx, manifestVariant(manifest, ctx.variant));
      ctx.elements.canvas.id = 'canvas';
      ctx.elements.canvas.addEventListener('contextmenu', event => event.preventDefault());
      bindInput(ctx);
    },

    async start(ctx) {
      if (started) return;
      void ctx.shell.resumeAudio();
      ctx.setLoading('Restoring registered Doom 3 data…', '', 5);
      const data = await ctx.dataClient.load(ownerData, {
        onProgress(detail) {
          if (detail.phase === 'checking-cache') ctx.setLoading(`Checking ${detail.key}…`);
          if (detail.phase === 'downloading') {
            const percent = detail.total ? Math.floor(detail.received * 100 / detail.total) : 0;
            ctx.setLoading(`Caching ${detail.key} from this container…`, `${percent}%`, Math.min(80, 5 + percent * 0.7));
          }
          if (detail.phase === 'restored') ctx.setLoading(`Restored ${detail.key} from this browser…`);
        }
      });
      document.documentElement.dataset.wasmDataSource = data.entries.every(entry => entry.cached) ? 'cache' : 'container';
      ctx.setLoading('Starting the Doom 3 engine…', '', 90);
      const canvas = ctx.elements.canvas;
      const offscreen = canvas.transferControlToOffscreen();
      const size = viewport(ctx);
      const preferences = ctx.preferences.values();
      worker = new Worker('/d3-worker.js');
      worker.onmessage = event => {
        const message = event.data || {};
        if (message.type === 'log') ctx.log(message.text);
        if (message.type === 'status') ctx.setLoading(message.text);
        if (message.type === 'engine-state') {
          state = message.state || 'menu';
          ctx.showRuntime(state);
        }
        if (message.type === 'ready') {
          state = message.state || 'menu';
          ctx.setLoading('', '', 100);
          ctx.showRuntime(state);
        }
        if (message.type === 'error') {
          state = 'crashed';
          ctx.log(`ERROR: ${message.text}`);
          ctx.setEngineState('crashed');
          ctx.setStatus(message.text, true);
        }
      };
      worker.onerror = event => {
        state = 'crashed';
        ctx.setEngineState('crashed');
        ctx.setStatus(`Doom 3 worker failed: ${event.message}`, true);
      };
      started = true;
      worker.postMessage({
        type: 'start', canvas: offscreen, variant: ctx.variant,
        entries: data.entries.map(entry => ({ path: entry.policy.path, file: entry.file })),
        width: size.width, height: size.height,
        playerName: preferences.playerName,
        engineArguments: profileArguments[preferences.qualityProfile] || profileArguments.high
      }, [offscreen]);
    },

    readEngineState() { return state; },
    resize(detail) {
      lastResize = detail;
      if (started) post({ type: 'resize', width: detail.requestedWidth, height: detail.requestedHeight });
    },
    pointerMove(detail) { if (started) post({ type: 'pointer-absolute', x: detail.x, y: detail.y }); },
    pointerButton(detail) { if (started) post({ type: 'pointer-button', button: detail.button, down: detail.pressed, x: detail.x, y: detail.y }); },
    inputCaptureChanged(captured) { if (started) post({ type: 'capture', captured }); },
    captureLost() { if (started) post({ type: 'open-menu' }); },
    preferencesChanged(values) {
      if (started) post({ type: 'preferences', playerName: values.playerName, engineArguments: profileArguments[values.qualityProfile] || profileArguments.high });
    }
  });
})();
