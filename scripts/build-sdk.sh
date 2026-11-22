#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/build-sdk.sh <UPSTREAM_DIR> <OUT_DIR>
UPSTREAM_DIR="${1:?missing UPSTREAM_DIR}"
OUT_DIR="${2:?missing OUT_DIR}"

mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$UPSTREAM_DIR"

export RUSTC_WRAPPER=""
export RUSTC_WORKSPACE_WRAPPER=""
export HORIZON_NO_AUDIO=1

echo "==> [1/4] 构建 Linux ARM64 Server Prebuilt SDK (prebuilt_game.py --server)"
python3 tools/prebuilt_game.py build "$WORK_DIR/prebuilt" --server

echo "==> [2/4] 使用 SDK 独立编译原生示例 Mod 进行冒烟验证"
python3 tools/prebuilt_game.py smoke "$WORK_DIR/prebuilt"

echo "==> [3/4] 打包 SDK 切片 (runtime / api / engine / build-data)"
python3 tools/prebuilt_game.py pack "$WORK_DIR/prebuilt" "$OUT_ABS"

echo "==> [4/4] 打包完整生成的 Mod API 源码 (api-source.tar.xz)"
python3 tools/sdk_api_source.py build "$WORK_DIR/api-source"
python3 tools/sdk_api_source.py archive "$WORK_DIR/api-source" "$OUT_ABS/api-source.tar.xz"

echo "==> SDK 构建完成:"
ls -lh "$OUT_ABS"
