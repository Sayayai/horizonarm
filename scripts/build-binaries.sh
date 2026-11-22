#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/build-binaries.sh <UPSTREAM_DIR> <OUT_DIR> [VERSION_LABEL]
UPSTREAM_DIR="${1:?missing UPSTREAM_DIR}"
OUT_DIR="${2:?missing OUT_DIR}"
VERSION_LABEL="${3:-dev}"

TARGET="aarch64-unknown-linux-gnu"
STAGE_DIR="$OUT_DIR/horizon-headless-server-linux-arm64"
ARCHIVE="$OUT_DIR/horizon-headless-server-linux-arm64.tar.gz"

mkdir -p "$STAGE_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"
STAGE_ABS="$OUT_ABS/horizon-headless-server-linux-arm64"
ARCHIVE_ABS="$OUT_ABS/horizon-headless-server-linux-arm64.tar.gz"

cd "$UPSTREAM_DIR"

export HORIZON_VERSION="$VERSION_LABEL"
export RUSTC_WRAPPER=""
export RUSTC_WORKSPACE_WRAPPER=""

echo "==> [1/3] 编译无头客户端 / 专用服核心引擎 (horizon-game --no-default-features)"
cargo build --release --locked \
  -p horizon-game --no-default-features --bin horizon-client

echo "==> [2/3] 编译控制端 (horizon-ctl)、服务端守护 (horizon-server) 与资源准备器 (horizon-prepare)"
cargo build --release --locked \
  -p horizon-client-lib --bin horizon-ctl \
  -p horizon-server --bin horizon-server \
  -p horizon-prepare --bin horizon-prepare

echo "==> [3/3] 收集产物并打包"
cp -f target/release/horizon-client "$STAGE_ABS/horizon-client"
cp -f target/release/horizon-client "$STAGE_ABS/horizon-engine"
cp -f target/release/horizon-ctl "$STAGE_ABS/horizon-ctl"
cp -f target/release/horizon-server "$STAGE_ABS/horizon-server"
cp -f target/release/horizon-prepare "$STAGE_ABS/horizon-prepare"

for f in LICENSE THIRD_PARTY_NOTICES.md; do
  [ -f "$f" ] && cp -f "$f" "$STAGE_ABS/$f"
done
[ -d LICENSES ] && cp -r LICENSES "$STAGE_ABS/LICENSES"

cat > "$STAGE_ABS/BUILD_INFO.txt" <<EOF
upstream_commit=$(git rev-parse HEAD)
upstream_date=$(git show -s --format=%cI HEAD)
target=$TARGET
version=$VERSION_LABEL
features=no-default-features (headless client + dedicated server only; no GUI launcher, no WASM std, no bots)
EOF

tar -C "$OUT_ABS" -czf "$ARCHIVE_ABS" "horizon-headless-server-linux-arm64"
(cd "$OUT_ABS" && sha256sum "$(basename "$ARCHIVE_ABS")" > "$(basename "$ARCHIVE_ABS").sha256")

echo "==> 完成: $ARCHIVE_ABS"
ls -lh "$ARCHIVE_ABS"
