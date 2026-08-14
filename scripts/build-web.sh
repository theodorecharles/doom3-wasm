#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
emsdk_root="${D3WASM_EMSDK:-/home/ted/emsdk}"
jobs="${JOBS:-2}"

if [[ ! -f "${emsdk_root}/emsdk_env.sh" ]]; then
	echo "Emscripten environment not found: ${emsdk_root}/emsdk_env.sh" >&2
	exit 1
fi

export EMSDK_QUIET=1
source "${emsdk_root}/emsdk_env.sh"

emcmake cmake -S "${repo_root}/neo" -B "${repo_root}/build/web" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DD3WASM_CLIENT=ON \
	-DDEDICATED=OFF
cmake --build "${repo_root}/build/web" --parallel "${jobs}"

node --check "${repo_root}/build/web/dhewm3.js"
test "$(od -An -tx1 -N4 "${repo_root}/build/web/dhewm3.wasm" | tr -d ' \n')" = "0061736d"
printf 'Built %s and %s\n' \
	"${repo_root}/build/web/dhewm3.js" \
	"${repo_root}/build/web/dhewm3.wasm"
