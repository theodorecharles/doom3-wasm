# doom3-wasm implementation runbook

Read `../RUNBOOK.md` first. It owns the shared asset, lifecycle, Docker,
graphics, input, testing, and one-browser-at-a-time rules. This repository is a
downstream-only dhewm3 port. Do not submit, discuss, or propose any of these
changes upstream. In particular, dhewm3 does not accept AI-assisted
contributions; all work stays in this downstream repository.

## Objective

Run the original Doom 3 single-player game, Doom 3 multiplayer client, and
Resurrection of Evil single-player game in a browser using the real dhewm3/id
Tech 4 C++ engine and owner-selected Steam PK4s. A compiled loader is not a
playable game: report base, multiplayer, and RoE separately and require an
actual rendered level before marking any one playable.

## Honest checkpoint — 2026-08-14

| Product | Emscripten build | Browser native init | Owner data | Menu/level | Playable |
| --- | --- | --- | --- | --- | --- |
| Doom 3 SP | Yes, hardlinked base gamecode | Yes | Picker plus loopback lazy mount verified | Decl initialization reached | No |
| Doom 3 MP | Same hardlinked base executable and authentic MP code/menus | Yes | Picker implemented; automated owner selection blocked | Not reached | No |
| RoE SP | Yes, separate hardlinked d3xp gamecode | Yes | Base+d3xp picker implemented; automated owner selection blocked | Not reached | No |
| Native dedicated server | Source target retained | Not rebuilt in this checkpoint | Not tested | N/A | No claim |

Both browser variants build from the current native dhewm3 source with
Emscripten 6.0.6. The base artifact links `neo/game`; the RoE artifact links
`neo/d3xp` with `_D3XP` and CTF definitions. There is no `dlopen` dependency in
the browser path.

The browser launcher and worker are real runtime integration, not a mock game:

- the user explicitly chooses a folder containing `base`, and `d3xp` for RoE;
- required PK4 names, exact Steam sizes, and ZIP/PK4 headers are checked before
  launch;
- `File` objects cross to a dedicated Worker without uploading them;
- WORKERFS exposes the PK4s read-only and reads slices on demand with
  `FileReaderSync`; multi-gigabyte archives are not copied into MEMFS or a
  generated `.data` bundle;
- the engine runs in that Worker with an `OffscreenCanvas` and a direct WebGL 2
  context seam;
- `/save` is a separate IDBFS mount, restored before native `main` and flushed
  every ten seconds/page hide;
- the directory handle, not the retail bytes, may be remembered in IndexedDB;
- the infinite native loop is replaced by `emscripten_set_main_loop`, and the
  disabled native async thread is folded into each cooperative browser frame;
- native condition variables and background download threads are not created
  in the non-pthread build;
- browser networking is deliberately loopback-only at this checkpoint.

No PK4 is tracked, staged under `build/web`, copied into the image, exposed by
the repository's production Nginx configuration, or accepted by an HTTP upload
route. Docker `/data` is reserved for a future native dedicated-server process
and Nginx returns 404 for `/data/`. The separate portfolio lab binds only to
127.0.0.1 and supplies its explicit `/local-data` range route from a read-only
owner mount.

### Serialized Chromium evidence

Chrome loaded `http://127.0.0.1:8094/?assetless=1` after the current rebuild.
The hidden diagnostic creates only a one-byte, non-retail `base/default.cfg` so
the native loaders can advance beyond the first file check. Tested one mode at
a time:

- Doom 3 SP entered native `main`, initialized SDL timer services, cooperative
  threading, loopback networking, WORKERFS/IDBFS paths, filesystem, and decl
  initialization; it stopped honestly at `_default material not found`.
- Doom 3 MP selected the same base engine/gamecode and reached the same honest
  asset boundary. This proves the executable selection, not a multiplayer
  connection or MP menu.
- RoE selected `dhewm3-roe.wasm`, searched `/owner-data/d3xp` before
  `/owner-data/base`, initialized decls, and stopped at the same missing retail
  material boundary. This proves the separate RoE build/route, not RoE gameplay.

After that picker-limited test, the loopback Docker lab loaded
`http://127.0.0.1:8086/?localdata=1` in Chrome. Exact size/header validation
passed, the worker opened every real `base/pak000.pk4` through `pak008.pk4` by
lazy same-origin ranges, the native filesystem reported their real checksums
and file counts, and decl initialization began without the former `_default`
missing-material failure. The status reached `Doom 3 single-player runtime
initialized`. No menu/frame/input/audio/gameplay claim is made yet.

## Build

Prerequisites: CMake, Ninja, Node.js, and an activated Emscripten SDK. The script
accepts `D3WASM_EMSDK` or `EMSDK_DIR`; it contains no workstation-specific SDK
or owner-data path.

```bash
cd /path/to/doom3-wasm
D3WASM_EMSDK=/path/to/emsdk JOBS=4 ./scripts/build-web.sh
```

The script configures and builds both variants:

```text
build/web-base/dhewm3.{js,wasm}  D3WASM_GAME=base
build/web-roe/dhewm3.{js,wasm}   D3WASM_GAME=roe
```

It then recreates the retail-free serving tree:

```text
build/web/index.html
build/web/d3-worker.js
build/web/dhewm3-base.js
build/web/dhewm3-base.wasm
build/web/dhewm3-roe.js
build/web/dhewm3-roe.wasm
```

Current artifact sizes are 460,609-byte base JS, 5,152,222-byte base WASM,
572,616-byte RoE JS, and 5,377,265-byte RoE WASM. Generated files are ignored;
source changes belong under `neo/`, `web/`, `scripts/`, and `docker/`.

## Local run and manual owner-data test

```bash
python3 -m http.server 8094 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8094/` in Chromium. Choose the Doom 3 installation root
that contains both `base/` and `d3xp/`, select one product, and grant read-only
access. For Doom 3 SP/MP, selecting the `base/` directory itself is also valid.
RoE requires a common parent because it needs both data sets.

The validated original-Steam asset set is:

```text
base/pak000.pk4 353159257       d3xp/pak000.pk4 538385153
base/pak001.pk4 229649726       d3xp/pak001.pk4     99336
base/pak002.pk4 416937674
base/pak003.pk4 317590154
base/pak004.pk4 237752384
base/pak005.pk4    552334
base/pak006.pk4    218751
base/pak007.pk4    192031
base/pak008.pk4     12243
```

The local multi-project staging convention is
`$PORTS_ROOT/data/doom3/{base,d3xp}`. Never copy it into this worktree or point
the static HTTP server at `$PORTS_ROOT/data`.

The portfolio's loopback-only Docker lab supports `?localdata=1` with optional
`mode=mp` or `mode=roe`. It validates exact PK4 sizes and ZIP headers, then the
engine worker creates lazy, read-only files backed by same-origin range
requests. This removes the picker for local testing without copying roughly two
gigabytes into browser memory. It is not enabled by the normal launcher URL.

Manual acceptance for the next run:

1. Verify the gate rejects a wrong folder without remembering its handle.
2. Choose the correct folder for Doom 3 SP and record the first native error or
   rendered frame.
3. Reload, choose Doom 3 MP, and verify the authentic multiplayer menu before
   attempting a connection.
4. Reload, choose RoE, confirm `/owner-data/d3xp` precedes base, and record the
   first native error or rendered frame.
5. Hard refresh once; a still-granted directory handle should resume without
   duplicating PK4s. Use **Forget folder permission** and verify the gate returns.
6. Close the tab and stop the server before testing another game repository.

`?assetless=1` is diagnostic-only and intentionally hidden from normal users.
It cannot prove menus, rendering, input, audio, SP, MP, or RoE gameplay.

## Renderer, input, and audio status

`neo/sys/glimp_emscripten.cpp` replaces native SDL-window GL setup with a
worker-owned WebGL 2 context on `#canvas`. Legacy GL emulation is enabled only
to get a first renderer probe. Doom 3's desktop ARB program and extension path
is not yet validated in WebGL; expect the first owner-data run to expose the
real shader/extension blocker. Do not claim the renderer works merely because
the WebGL bridge compiles.

SDL video initialization blocked inside the worker, so the current platform
initializes SDL timers only. Keyboard, text, mouse, pointer lock, resize, focus,
and audio event bridges are not implemented yet. After the first rendered
menu/frame, relay main-thread browser events to the Worker and translate them
into id Tech 4 events; keep OS cursor outside capture and the engine cursor in
menus/in-world GUIs. Audio has not been initialized or tested.

## Multiplayer and Docker status

The base build retains Doom 3's authentic multiplayer code and menus, but
browser networking is loopback-only and the product selector does not itself
join or host a match. A native dedicated server plus same-origin
WebSocket-to-UDP bridge remains future work. Rebuild and test two clients before
claiming multiplayer.

The Dockerfile serves only the six-file web tree and retains slots for native
client/server binaries. `scripts/build-docker.sh` intentionally refuses retail
files and unexpected web artifacts. No image was built in this checkpoint;
native/server artifacts and container entrypoint/lifecycle need a fresh audit
before the image is called operational.

## Exact verification run

- `D3WASM_EMSDK=/home/ted/emsdk JOBS=4 ./scripts/build-web.sh` — pass; base
  283-target and RoE 285-target graphs linked (incremental verification rebuilt
  the changed platform objects and both final executables).
- `node --check` for both generated engine JS files and `d3-worker.js` — pass.
- Inline launcher JavaScript compilation with Node `vm.Script` — pass.
- WASM magic `00 61 73 6d` for both artifacts — pass.
- staged launcher/worker equality — pass.
- shell syntax for `build-web.sh` and `build-docker.sh` — pass.
- tracked and staged `.pk4`, `.wad`, or `.pak` search — zero.
- tracked executable/config absolute `/home/ted/Development` paths — zero.
- unauthenticated PUT/WebDAV and public `/data` alias search — zero.
- `git diff --check` — pass.
- serialized Chrome SP, MP selection, then RoE selection — native initialization
  and expected `_default material not found` diagnostic boundary, no tab hang.

## Prioritized blockers

1. Manually grant the real owner directory and capture the first renderer
   failure/frame. This is the only legitimate way past the current material
   boundary.
2. Translate or replace unsupported desktop ARB shader/extension behavior with
   WebGL 2 / GLSL ES 3.00 until the authentic main menu renders.
3. Implement browser-to-worker input, pointer-lock/cursor, resize/focus, and
   SDL/Web Audio paths, then launch one Doom 3 base level.
4. Repeat an actual RoE level independently; never infer RoE playability from
   the base game.
5. Preserve the authentic multiplayer menu, implement the transport/idle
   dedicated-server lifecycle, and test two real browser clients.
6. Rebuild/audit native client/server and Docker only after the browser client
   reaches a menu.

Upstream contacted: no. Upstream submission: forbidden.
