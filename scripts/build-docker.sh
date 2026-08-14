#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${IMAGE_REPO:-theodorecharles/doom3-wasm}:${IMAGE_TAG:-dev}"

for artifact in \
  build/web/index.html \
  build/web/d3-worker.js \
  build/web/dhewm3-base.js \
  build/web/dhewm3-base.wasm \
  build/web/dhewm3-roe.js \
  build/web/dhewm3-roe.wasm \
  build/native/dhewm3 \
  build/native/base.so \
  build/native/d3xp.so \
  build/server/dhewm3ded \
  build/server/base.so \
  build/server/d3xp.so; do
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
  -path "$repo_root/build/web/index.html" -o \
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

docker build --platform linux/amd64 \
  --build-arg "VCS_REF=$(git -C "$repo_root" rev-parse HEAD)" \
  --tag "$image" "$repo_root"
echo "Built $image"
