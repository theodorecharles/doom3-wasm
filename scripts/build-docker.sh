#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image_repo="${IMAGE_REPO:-theodorecharles/doom3-wasm}"
image_tag="${IMAGE_TAG:-dev}"
framework_dir="${D3WASM_FRAMEWORK_DIR:-${repo_root}/../wasm-game-framework}"

for artifact in \
  build/web/wasm-game.json \
  build/web/wasm-game-data.json \
  build/web/wasm-game-framework.json \
  build/web/game-adapter.js \
  build/web/doom3.ico \
  build/web/doom3-pwa.svg \
  build/web/roe.png \
  build/web/d3-worker.js \
  build/web/dhewm3-base.js \
  build/web/dhewm3-base.wasm \
  build/web/dhewm3-roe.js \
  build/web/dhewm3-roe.wasm; do
  test -s "$repo_root/$artifact" || {
    echo "Missing $artifact; run scripts/build-web.sh and the native/server builds first." >&2
    exit 1
  }
done

if find "$repo_root/build/web" -type f \( -iname '*.pk4' -o -iname '*.pak' \) -print -quit | grep -q .; then
  echo "Refusing to build: retail game data found under build/web." >&2
  exit 1
fi

unexpected_file="$(find "$repo_root/build/web" -type f ! \( \
  -path "$repo_root/build/web/wasm-game.json" -o \
  -path "$repo_root/build/web/wasm-game-data.json" -o \
  -path "$repo_root/build/web/wasm-game-framework.json" -o \
  -path "$repo_root/build/web/game-adapter.js" -o \
  -path "$repo_root/build/web/doom3.ico" -o \
  -path "$repo_root/build/web/doom3-pwa.svg" -o \
  -path "$repo_root/build/web/roe.png" -o \
  -path "$repo_root/build/web/d3-worker.js" -o \
  -path "$repo_root/build/web/dhewm3-base.js" -o \
  -path "$repo_root/build/web/dhewm3-base.wasm" -o \
  -path "$repo_root/build/web/dhewm3-roe.js" -o \
  -path "$repo_root/build/web/dhewm3-roe.wasm" \
\) -print -quit)"
if [[ -n "$unexpected_file" ]]; then
  echo "Refusing to build: unexpected file under build/web: $unexpected_file" >&2
  exit 1
fi

for variant in suite doom3 doom3-mp roe; do
  if [[ "$variant" == suite ]]; then
    image="${image_repo}:${image_tag}"
  else
    image="${image_repo}:${variant}-${image_tag}"
  fi
  "${framework_dir}/scripts/build-static-image.sh" "$repo_root/build/web" "$image" "$variant"
done
echo "Built Doom 3 suite plus doom3, doom3-mp, and roe locked images."
