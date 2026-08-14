# doom3-wasm implementation runbook

Read `/home/ted/Development/WASM_PORTS_RUNBOOK.md` first. It defines shared shell, data, lifecycle, graphics, input, Docker, testing, and coordination rules. This file defines the Doom 3 and Resurrection of Evil implementation path.

## Objective

Ship Doom 3 Single Player, Resurrection of Evil Single Player, and Doom 3 Multiplayer in a browser using the real id Tech 4 engine/game code and legally supplied Steam PK4s. Preserve authentic menus/HUD/GUIs, campaigns, AI, scripted events, saves, cinematics, renderer, stencil shadows where feasible, audio, console, multiplayer, and dedicated server.

## Current checkpoint

- Downstream repository: `theodorecharles/doom3-wasm`.
- Implementation base: `dhewm/dhewm3`.
- Work branch: `devel`.
- Original id Doom 3 GPL source belongs in ignored `references/doom3-source/`.
- dhewm3 provides SDL, CMake, widescreen fixes, Doom 3 and RoE data compatibility, and a `DEDICATED=ON` native server build.
- dhewm3 has no maintained Emscripten target. This is a real id Tech 4 platform and renderer port.
- Steam apps 9050 and 9070 are not currently complete. `/home/ted/.steam/debian-installation/steamapps/common/Doom 3` contains only partial data. Asset/title/playability milestones are blocked until Steam finishes both Doom 3 and Resurrection of Evil.

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

Then add an Emscripten CMake preset/toolchain path:

```bash
source /home/ted/emsdk/emsdk_env.sh
emcmake cmake -S neo -B build/web -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DD3WASM_CLIENT=ON \
  -DDEDICATED=OFF
cmake --build build/web --parallel 2
```

`D3WASM_CLIENT` is a downstream option to create; it should make platform choices explicit rather than rely on a giant permanent command. Compile immediately and fix one blocker at a time.

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

Implement a read-only lazy PK4 filesystem backed by same-origin HTTP range/chunk requests and IndexedDB/OPFS. Central directory metadata may be indexed early, but file contents load on demand. Writable saves/configs live in a separate persistent mount. Code bundle version changes must not invalidate unchanged retail PK4 caches.

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

## First worker assignment

1. Re-check Steam app 9050/9070 completion and do not modify the Steam installation.
2. Prove native client and dedicated configurations without retail data if necessary.
3. Add the smallest Emscripten CMake option/platform stub and compile immediately.
4. Classify the first 20 compiler/linker blockers by platform, renderer, audio, threading, filesystem, or game-module loading; fix the first, not all speculatively.
5. Produce a substantial WASM artifact and thin diagnostic launcher before asset work.
6. Return the exact engine-init browser test handoff to Luna; do not use Chrome.
7. Commit and push `devel`.

## Status handoff

Report Doom 3 SP, RoE SP, and MP separately; exact commands; artifact paths; Steam state; browser test request; renderer/platform blocker; and `Upstream contacted: no`.
