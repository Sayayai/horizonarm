#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/build-sdk.sh <UPSTREAM_DIR> <OUT_DIR> [--server|--client]
UPSTREAM_DIR="${1:?missing UPSTREAM_DIR}"
OUT_DIR="${2:?missing OUT_DIR}"
MODE="${3:---server}"

mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$UPSTREAM_DIR"

export RUSTC_WRAPPER=""
export RUSTC_WORKSPACE_WRAPPER=""
export HORIZON_NO_AUDIO=1

# 修复官方 tools/prebuilt_game.py 中 api_route 遗漏 GAME_LIBRARIES[1] (horizon_mod_wasm) 导致客户端 SDK 报 DSO missing from command line 的 Bug
python3 -c '
with open("tools/prebuilt_game.py", "r") as f:
    c = f.read()
target = "\"--extern\", f\"{GAME_LIBRARIES[0]}={dylib(deps, GAME_LIBRARIES[0])}\","
replacement = "*(flag for lib in GAME_LIBRARIES for flag in (\"--extern\", f\"{lib}={dylib(deps, lib)}\")),"
if target in c:
    c = c.replace(target, replacement)
    with open("tools/prebuilt_game.py", "w") as f:
        f.write(c)
    print("==> 成功修复 api_route 链接参数遗漏 horizon_mod_wasm 的 Bug")
'

BUILD_ARGS=()
if [[ "$MODE" == "--server" ]]; then
  BUILD_ARGS=("--server")
  echo "==> [1/2] 构建 Server 原生 Mod SDK (prebuilt_game.py build --server)"
else
  echo "==> [1/2] 构建 Client 原生 Mod SDK (prebuilt_game.py build)"
fi

python3 tools/prebuilt_game.py build "$WORK_DIR/prebuilt" "${BUILD_ARGS[@]}"

echo "==> [2/2] 打包原生 Mod SDK 切片 (runtime / api / engine / build-data / surface)"
python3 tools/prebuilt_game.py pack "$WORK_DIR/prebuilt" "$OUT_ABS"

echo "==> SDK 切片打包完成:"
ls -lh "$OUT_ABS"
