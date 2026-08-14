#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
emsdk_root="${D3WASM_EMSDK:-${EMSDK_DIR:-}}"
jobs="${JOBS:-2}"

if command -v emcc >/dev/null 2>&1 && command -v emcmake >/dev/null 2>&1; then
	:
elif [[ -n "${emsdk_root}" && -f "${emsdk_root}/emsdk_env.sh" ]]; then
	export EMSDK_QUIET=1
	source "${emsdk_root}/emsdk_env.sh"
else
	echo "Activate Emscripten first, or set D3WASM_EMSDK/EMSDK_DIR to an emsdk checkout." >&2
	exit 1
fi

emcmake cmake -S "${repo_root}/neo" -B "${repo_root}/build/web" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DD3WASM_CLIENT=ON \
	-DDEDICATED=OFF
cmake --build "${repo_root}/build/web" --parallel "${jobs}"

node --check "${repo_root}/build/web/dhewm3.js"
test "$(od -An -tx1 -N4 "${repo_root}/build/web/dhewm3.wasm" | tr -d ' \n')" = "0061736d"

# Keep the browser checkpoint self-contained without copying retail data.
install -m 0644 "${repo_root}/web/index.html" "${repo_root}/build/web/index.html"
printf 'Built %s and %s\n' \
	"${repo_root}/build/web/dhewm3.js" \
	"${repo_root}/build/web/dhewm3.wasm"
