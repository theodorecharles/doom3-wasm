# doom3-wasm implementation runbook

Read `../RUNBOOK.md` first. It defines shared shell, data, lifecycle, graphics, input, Docker, testing, and coordination rules. This file defines the Doom 3 and Resurrection of Evil implementation path.

## Objective

Ship Doom 3 Single Player, Resurrection of Evil Single Player, and Doom 3 Multiplayer in a browser using the real id Tech 4 engine/game code and legally supplied Steam PK4s. Preserve authentic menus/HUD/GUIs, campaigns, AI, scripted events, saves, cinematics, renderer, stencil shadows where feasible, audio, console, multiplayer, and dedicated server.

## Verified checkpoint (2026-08-14)

- Downstream repository: `theodorecharles/doom3-wasm`.
- Implementation base: `dhewm/dhewm3`.
- Work branch: `devel`.
- Original id Doom 3 GPL source belongs in ignored `references/doom3-source/`.
- dhewm3 provides SDL, CMake, widescreen fixes, Doom 3 and RoE data compatibility, and a `DEDICATED=ON` native server build.
- dhewm3 has no maintained Emscripten target. This is a real id Tech 4 platform and renderer port.
- Steam apps 9050 and 9070 report `StateFlags 4`. The owner installation remains untouched at `/home/ted/.steam/debian-installation/steamapps/common/Doom 3`: the 13 base PK4s total 1,563,140,716 bytes and the 6 `d3xp` PK4s total 546,020,038 bytes. No PK4 is in this worktree, image, or web root.
- `./scripts/build-web.sh` regenerated the Emscripten build from the current native dhewm3 source and completed all 283 targets with Emscripten 6.0.6. It emits `build/web/index.html` (3,455 bytes), `dhewm3.js` (341,806 bytes), and `dhewm3.wasm` (5,176,331 bytes).
- The web build hardlinks the Doom 3 base game (`BASE=ON`, `D3XP=OFF`). C++ exception catching is enabled, memory grows from 128 MiB up to 2 GiB, and the context target is WebGL 2.
- The infinite native loop now uses `emscripten_set_main_loop`. The native async thread is disabled for this single-thread checkpoint and `Async()` runs before each browser frame. Native frame throttling no longer sleeps the browser main thread.
- The launcher starts the real engine bundle on an explicit click and captures stdout/stderr/abort messages in the page. It does not request, upload, or serve retail data.
- JavaScript syntax, WASM magic, staged-launcher equality, and HTTP delivery were checked locally. Chrome runtime execution was not performed: Chrome was offline after the preceding serialized Quake 4 test. See the exact handoff below.

### Current status by product

| Product | Compiles for web | Browser initialized | Retail data loaded | Playable |
| --- | --- | --- | --- | --- |
| Doom 3 base/SP | Yes, hardlinked | Not tested in Chrome | No | No |
| Doom 3 multiplayer client | Same base executable, unproven | No | No | No |
| Resurrection of Evil/SP | No; `D3XP=OFF` in this target | No | No | No |
| Native dedicated server | Older baseline artifacts exist; not rebuilt after the workspace move | N/A | Not tested | No claim |

Do not infer title-screen, renderer, input, sound, SP, MP, or RoE support from the successful compile.

### Docker checkpoint

- The Dockerfile stages the launcher and engine artifacts at the Nginx document root. `/data` remains available only for future native-server work; Nginx explicitly returns 404 for `/data/` and has no upload method.
- The unauthenticated WebDAV `PUT` uploader and public `/data` alias from the discarded Luna diff were removed. Never restore that design.
- The image was not rebuilt in this checkpoint. `scripts/build-docker.sh` still requires native client/server artifacts, and those need a clean current-path rebuild plus an image-runtime dependency audit before this image is called operational.

## Downstream-only rule

Do not submit anything upstream. Do not open or comment on dhewm3 or id Software pull requests, issues, discussions, or releases. Do not message maintainers. Never push to `upstream`.

dhewm3 explicitly states that it does not accept AI-assisted contributions. Respect that completely: all generated code and documentation stays only in `theodorecharles/doom3-wasm`; never propose it back to dhewm3.

## Source authority

Use this order:

1. legally installed Doom 3/RoE in Steam after download completes;
2. ignored id GPL source for original engine behavior;
3. dhewm3 for maintained engine/platform/game behavior;
4. `wolfet-wasm` only for generic browser-shell and operational patterns.

Do not use BFG Edition data: dhewm3's documentation says BFG Edition is unsupported. Target the original Doom 3 1.3.1 and RoE data layouts.

## Native baseline

Before web changes, prove the standard client and dedicated build:

```bash
cmake -S neo -B build/native -DCMAKE_BUILD_TYPE=Release
cmake --build build/native --parallel

cmake -S neo -B build/server -DCMAKE_BUILD_TYPE=Release -DDEDICATED=ON
cmake --build build/server --parallel
```

The maintained wrapper configures the Emscripten CMake toolchain with:

```bash
source /home/ted/emsdk/emsdk_env.sh
emcmake cmake -S neo -B build/web -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DD3WASM_CLIENT=ON \
  -DDEDICATED=OFF
cmake --build build/web --parallel 2
```

`D3WASM_CLIENT` is the downstream option that makes platform choices explicit rather than relying on a giant permanent command. Compile immediately and fix one blocker at a time.

## First platform reductions

For the first title-screen milestone:

- single-thread engine/game first; disable asynchronous native worker threads;
- SDL2 Emscripten video/input;
- WebGL 2/GLES-compatible renderer path;
- no dlopen or platform DLL loading; statically link or Emscripten side-module game code deliberately;
- disable native crash handlers, process spawning, editor tools, CD-key/native dialogs, and LAN discovery where unsupported;
- replace blocking main loop with `emscripten_set_main_loop` or an equivalent non-blocking callback;
- temporarily disable voice capture and optional curl/network downloads;
- use SDL/Web Audio-compatible playback before attempting OpenAL feature parity.

Guard platform changes with `__EMSCRIPTEN__` and keep native builds passing.

## Renderer strategy

Desktop OpenGL assumptions are the first major technical gate. Inventory fixed-function calls, ARB vertex/fragment programs, stencil shadow paths, framebuffer use, texture formats, and extension checks before deciding the smallest WebGL 2 translation.

Prefer an existing GLES-compatible id Tech 4 renderer path only after its license and compatibility are verified. Do not import Android port code casually. If translating dhewm3 directly:

1. Create a WebGL 2 context and truthful capability table.
2. Replace ARB programs with GLSL ES 3.00 shaders.
3. Make VBO/index-buffer formats WebGL-valid.
4. Implement depth/stencil state without unsupported desktop enums.
5. Restore materials, interactions, shadow volumes, particles, GUIs, and post-processing incrementally.
6. Treat context loss/recreation as a real browser state.

Acceptance order: clear/frame, static world, materials, light interactions, animated entities, particles, in-world GUIs, shadows, post-processing, cinematics.

## Retail data and lazy filesystem

After Steam completes, validate actual files under:

```text
/data/base/pak000.pk4 ... pak008.pk4 (actual installed set is authoritative)
/data/d3xp/*.pk4
```

Do not commit, publish, or bake them into the Docker image. Doom 3/RoE data is multi-gigabyte; never preload every PK4 into WASM linear memory or one `index.data` blob.

Do not expose `/data`, accept browser uploads, or serve retail files over HTTP. The browser must obtain owner data locally through an explicit directory/file picker and retain user-granted handles where supported. Implement a read-only lazy PK4 filesystem backed by `FileSystemFileHandle` reads and an OPFS/IndexedDB index; do not copy multi-gigabyte archives into MEMFS or WASM linear memory. Central-directory metadata may be indexed early, file contents load on demand, and writable saves/configs live in a separate persistent mount. Code-bundle changes must not invalidate unchanged owner PK4 indexes.

Docker-mounted `/data/base` and `/data/d3xp` are for the native dedicated server only. They must never appear under the HTTP document root or an Nginx alias. Every browser client supplies its own legally owned data locally.

## Campaign/menu routing

The authentic engine UI must expose:

- Doom 3
  - New Game
  - Load/Save
- Resurrection of Evil
  - New Game
  - Load/Save
- Multiplayer
  - Join Game
  - Host/Local Match where useful
- Options
- Credits

Use id Tech 4 GUI/menu definitions and legal assets. Do not recreate them in HTML. Switching Doom 3 to RoE must sync saves/config, change the correct game directory/module (`d3xp`), and restart only the engine state that actually requires it. Namespaces for base and RoE saves must not collide.

Single Player never wakes the dedicated server. Multiplayer intent wakes it before connection begins.

## Single-player acceptance

Test Doom 3 and RoE separately:

- new game/difficulty;
- first interactive level;
- AI, weapons, physics, doors, triggers, PDA/in-world GUIs, particles, lighting/shadows, cinematics, scripted events, and map transition;
- pause/death/reload;
- save, page reload, persistent restore, load;
- campaign switch base -> RoE -> base without corrupting saves or renderer/input.

Do not call RoE supported because its menu appears; an actual `d3xp` level must render and run.

## Multiplayer

Build a native dhewm3 dedicated server and preserve Doom 3 protocol behind a same-origin WebSocket bridge to native UDP. Test two real browser clients: server wake, connect, lobby, map load, movement, combat, chat, scoreboard, death/respawn, map transition, and reconnect.

Do not promise bot backfill unless a compatible bot gamecode package has verified licensing, navigation data, and dedicated-server support. Campaign demons are not multiplayer bots.

## Input, GUI, and cursor

id Tech 4 uses interactive 2D and in-world GUIs, so pointer mapping must share the exact render viewport transform. Test landing form, engine menu, in-world terminals, PDA, console text/history, gameplay pointer lock, cinematics, pause, death/reload, multiplayer chat/scoreboard, and focus loss.

One cursor only: OS cursor outside canvas; engine cursor in menus/GUIs; relative deltas only during captured gameplay. Browser shortcuts work outside capture.

## Graphics profiles

Build Low/Medium/High/Ultra from verified id Tech 4 controls: resolution scale, texture compression/detail, anisotropy, interaction/shader quality, shadows, particles, decals, post-processing, antialiasing where WebGL supports it, and view distance. Dynamic 30/60/120 FPS follows shared hysteresis and never disables gameplay-critical lights or in-world GUI readability.

## Docker defaults

The image contains the web engine, native dedicated server, bridge, and no retail PK4s:

```text
HTTP_PORT=8088
GAME_SLOTS=8
KEEP_ALIVE=false
IDLE_TIMEOUT=15m
GAME_MODE=vanilla
```

Use `/data/base`, `/data/d3xp`, and `/data/custom_maps`. Startup clearly reports incomplete Doom 3 versus missing RoE. Build `linux/amd64` first.

## Build and local run

```bash
cd /path/to/doom3-wasm
./scripts/build-web.sh
python3 -m http.server 8094 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8094/`. The page deliberately does not start the engine until **Start assetless engine smoke** is clicked. Do not point this server at the Steam installation or copy PK4s into `build/web`.

The first build after moving a checkout may fail because an ignored `build/web/CMakeCache.txt` contains the old absolute path. Remove only that generated directory with:

```bash
cmake -E remove_directory build/web
./scripts/build-web.sh
```

## Serialized Chrome handoff

Chrome was unavailable for this checkpoint, so this remains an exact test request rather than a claimed result:

1. Ensure no other id Tech browser smoke is running.
2. Start the local server using the command above.
3. In Chrome, open `http://127.0.0.1:8094/?smoke=20260814`.
4. Confirm the page initially says `Not started` and no `dhewm3.js`/`.wasm` request occurs before the click.
5. Click **Start assetless engine smoke** once.
6. Confirm both artifacts return HTTP 200, the page reports `WASM runtime initialized`, and capture the final engine log/abort text.
7. A clean missing-retail-data stop is the expected assetless outcome. A freeze, tab crash, JavaScript syntax error, missing `Module.canvas`, pthread creation, or a blocking-loop warning is a regression.

If the engine gets beyond the data check, stop after recording the first renderer/platform error. Do not start a renderer-polish loop in this test.

## Exact tests run

- `./scripts/build-web.sh` — pass, 283/283 targets linked.
- `node --check build/web/dhewm3.js` — pass.
- WASM magic `00 61 73 6d` — pass.
- `cmp web/index.html build/web/index.html` — pass.
- Python HTTP server HEAD requests for `/`, `/dhewm3.js`, and `/dhewm3.wasm` — HTTP 200 with correct JavaScript/WASM MIME types.
- Search for tracked/worktree PK4/WAD retail files — zero.
- Search for `dav_methods`, `/data` alias, `PUT`, and the Luna data-ingest module — zero.
- `git diff --check` — pass.
- Chrome runtime smoke — not run; browser unavailable after the prior Quake 4 crash.

## Next blockers

1. Run the serialized assetless Chrome handoff and record the first real engine-init gate.
2. Build a local-picker-backed lazy PK4 filesystem using file handles/OPFS, never HTTP or bulk MEMFS preload.
3. Translate the desktop ARB program renderer to WebGL 2/GLSL ES. Compilation does not prove this renderer path.
4. Give RoE its own `BASE=OFF`, `D3XP=ON`, `HARDLINK_GAME=ON` web artifact and test it separately.
5. Rebuild/audit the native dedicated server and add the WebSocket-to-UDP multiplayer bridge only after the base client initializes.

Report Doom 3 SP, RoE SP, and MP separately on every handoff. Upstream contacted: no. Upstream submission: forbidden.
