#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
emsdk_root="${D3WASM_EMSDK:-${EMSDK_DIR:-}}"
jobs="${JOBS:-2}"
base_build="${D3WASM_BASE_BUILD_DIR:-${repo_root}/build/web-base}"
roe_build="${D3WASM_ROE_BUILD_DIR:-${repo_root}/build/web-roe}"
web_dir="${D3WASM_WEB_DIR:-${repo_root}/build/web}"
framework_dir="${D3WASM_FRAMEWORK_DIR:-${repo_root}/../wasm-game-framework}"

framework_version="$(node -p "require('${framework_dir}/package.json').version")"
if [[ "${framework_version}" != "0.7.0" ]]; then
	echo "doom3-wasm requires wasm-game-framework 0.7.0, found ${framework_version}." >&2
	exit 1
fi

if command -v emcc >/dev/null 2>&1 && command -v emcmake >/dev/null 2>&1; then
	:
elif [[ -n "${emsdk_root}" && -f "${emsdk_root}/emsdk_env.sh" ]]; then
	export EMSDK_QUIET=1
	source "${emsdk_root}/emsdk_env.sh"
else
	echo "Activate Emscripten first, or set D3WASM_EMSDK/EMSDK_DIR to an emsdk checkout." >&2
	exit 1
fi

build_game() {
	local game="$1"
	local build_dir="$2"
	emcmake cmake -S "${repo_root}/neo" -B "${build_dir}" -G Ninja \
		-DCMAKE_BUILD_TYPE=Release \
		-DD3WASM_CLIENT=ON \
		-DD3WASM_GAME="${game}" \
		-DDEDICATED=OFF
	cmake --build "${build_dir}" --parallel "${jobs}"
}

build_game base "${base_build}"
build_game roe "${roe_build}"

cmake -E remove_directory "${web_dir}"
mkdir -p "${web_dir}"
install -m 0644 "${base_build}/dhewm3.js" "${web_dir}/dhewm3-base.js"
install -m 0644 "${base_build}/dhewm3.wasm" "${web_dir}/dhewm3-base.wasm"
install -m 0644 "${roe_build}/dhewm3.js" "${web_dir}/dhewm3-roe.js"
install -m 0644 "${roe_build}/dhewm3.wasm" "${web_dir}/dhewm3-roe.wasm"
install -m 0644 "${repo_root}/web/d3-worker.js" "${web_dir}/d3-worker.js"
install -m 0644 "${repo_root}/web/game-adapter.js" "${web_dir}/game-adapter.js"
install -m 0644 "${repo_root}/web/wasm-game.json" "${web_dir}/wasm-game.json"
install -m 0644 "${repo_root}/web/wasm-game-data.json" "${web_dir}/wasm-game-data.json"
install -m 0644 "${repo_root}/neo/sys/win32/rc/res/doom.ico" "${web_dir}/doom3.ico"
install -m 0644 "${repo_root}/dist/linux/share/icons/hicolor/scalable/apps/org.dhewm3.Dhewm3.svg" "${web_dir}/doom3-pwa.svg"
install -m 0644 "${repo_root}/neo/sys/aros/ROE.png" "${web_dir}/roe.png"

metadata_dir="$(mktemp -d -t doom3-framework.XXXXXX)"
trap 'rm -rf -- "${metadata_dir}"' EXIT
"${framework_dir}/scripts/install-browser-package.sh" "${metadata_dir}" copy >/dev/null
install -m 0644 "${metadata_dir}/wasm-game-framework.json" "${web_dir}/wasm-game-framework.json"

node --check "${web_dir}/dhewm3-base.js"
node --check "${web_dir}/dhewm3-roe.js"
node --check "${web_dir}/d3-worker.js"
node --check "${web_dir}/game-adapter.js"
for wasm in "${web_dir}/dhewm3-base.wasm" "${web_dir}/dhewm3-roe.wasm"; do
	test "$(od -An -tx1 -N4 "${wasm}" | tr -d ' \n')" = "0061736d"
done
cmp "${repo_root}/web/d3-worker.js" "${web_dir}/d3-worker.js"
cmp "${repo_root}/web/game-adapter.js" "${web_dir}/game-adapter.js"
test ! -e "${web_dir}/index.html"
test ! -e "${web_dir}/app.webmanifest"
test ! -e "${web_dir}/service-worker.js"

printf 'Built retail-data-free Doom 3 browser clients:\n'
for artifact in \
	"${web_dir}/dhewm3-base.js" "${web_dir}/dhewm3-base.wasm" \
	"${web_dir}/dhewm3-roe.js" "${web_dir}/dhewm3-roe.wasm"; do
	printf '  %s (%s bytes)\n' "${artifact}" "$(stat -c '%s' "${artifact}")"
done
printf 'Owner PK4s are provisioned under /data and cached privately by the framework; they are never copied into build/web.\n'
