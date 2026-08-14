# Doom 3 WebAssembly runbook

Status: **Still in development**

This downstream ports the native dhewm3 engine to Emscripten for Doom 3,
Doom 3 multiplayer, and Resurrection of Evil. It does not reuse an existing
WebAssembly port and it does not include retail PK4s.

## Rules

- Do not submit, push, file, or discuss this work upstream.
- Keep all changes in this downstream repository.
- Never commit or bake retail `base`/`d3xp` data into source or image layers.
- Keep `/data` private; the HTTP server must return 404 for `/data` and every
  child path.
- Test Doom 3 SP, Doom 3 MP, and RoE as distinct variants.

## Canonical browser contract

The repository pins `wasm-game-framework` 0.7.0 at public commit
`536d919ef6e6cd171aa826812db9f888ffbf04a3`.

Downstream owns only:

- `web/wasm-game.json`: declarative shell, variant, PWA, icon, viewport,
  graphics, and fullscreen metadata;
- `web/wasm-game-data.json`: exact owner-data policy;
- `web/game-adapter.js`: framework-to-engine state/input/data adapter;
- `web/d3-worker.js`: worker bootstrap and Emscripten filesystem mounts;
- engine JS/WASM and source-licensed icon assets.

There is no downstream `index.html`, shell stylesheet, service worker, or web
manifest. The framework generates those artifacts and provides the
`WasmGameFramework` API, `wasm-game-framework-*` events/classes, owner-data
container provisioning, IndexedDB browser cache, remembered launch fullscreen,
variant-aware PWA metadata, responsive canvas policy, and security headers.

## Variants and images

- `doom3`: Doom 3 single player — **Still in development**
- `doom3-mp`: Doom 3 multiplayer — **Still in development**
- `roe`: Doom 3: Resurrection of Evil — **Still in development**

`scripts/build-docker.sh` builds one suite image plus a locked image for each
variant. Doom 3 SP and MP use the exact nine-file base policy. RoE adds the exact
two-file `d3xp` policy. All variants share one namespace so the browser stores
identical base PK4s once.

## Owner data flow

The owner mounts registered data at `/data/base` and, for RoE, `/data/d3xp`.
On first use the framework streams the exact manifest files from the container
into its private browser cache. Later launches restore unchanged files from
IndexedDB. The worker mounts browser `File` objects read-only through WORKERFS
at `/owner-data`; saves/configuration use IDBFS at `/save`.

Retail files are never copied into `build/web`. Docker staging rejects every
`.pk4` and `.pak` under that directory.

## Build

```bash
cd /home/ted/Development/wasm/doom3-wasm
source /home/ted/emsdk/emsdk_env.sh
JOBS=4 ./scripts/build-web.sh
IMAGE_REPO=local/doom3-wasm IMAGE_TAG=dev ./scripts/build-docker.sh
```

The build creates two native-source Emscripten clients (`base` and `roe`) and
four framework images (suite, Doom 3 SP, Doom 3 MP, RoE). The suite and locked
0.7.0 images pass HTTP bootstrap/metadata, WASM range, and `/data` isolation
checks.

## Verified browser boundary (2026-08-14)

A serialized Chrome test with the owner Steam data verified:

- browser owner-data caching and restore;
- all nine base PK4s mounted by the real native engine;
- a worker-safe direct WebGL 2 context on the transferred OffscreenCanvas;
- no selector/`document` access during context creation or resize;
- decl loading and renderer capability discovery.

The current blocker is `R_ReloadARBPrograms`: the desktop ARB program path is
not a valid final WebGL 2 renderer. Implement valid GLSL ES 3.00 shaders and
reach the authentic menu before changing any game status to **Live**. Browser
audio also remains disabled when OpenAL cannot open a device.

## Acceptance sequence

1. Replace/translate the ARB program path for WebGL 2.
2. Render the authentic Doom 3 SP, MP, and RoE menus.
3. Verify dynamic aspect-correct sizing and 4:3 native menu pointer mapping.
4. Start Doom 3 campaign, an RoE campaign, and one MP map.
5. Verify WASD, relative mouse, Escape/menu state, console editing, and normal
   browser shortcuts outside capture.
6. Restore browser audio and persistent saves.
7. Rebuild all images and test PWA metadata, service-worker behavior, headers,
   ranges, `/data` isolation, and all three variants in serialized Chrome.

Upstream contacted: **no**.
