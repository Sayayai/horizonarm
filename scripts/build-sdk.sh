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
