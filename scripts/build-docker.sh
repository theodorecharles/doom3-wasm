#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${IMAGE_REPO:-theodorecharles/doom3-wasm}:${IMAGE_TAG:-dev}"

for artifact in \
  web/index.html \
  build/web/dhewm3.js \
  build/web/dhewm3.wasm \
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

docker build --platform linux/amd64 \
  --build-arg "VCS_REF=$(git -C "$repo_root" rev-parse HEAD)" \
  --tag "$image" "$repo_root"
echo "Built $image"
