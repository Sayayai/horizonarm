#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/build-binaries.sh <UPSTREAM_DIR> <OUT_DIR> [VERSION_LABEL] [ARCH]
UPSTREAM_DIR="${1:?missing UPSTREAM_DIR}"
OUT_DIR="${2:?missing OUT_DIR}"
VERSION_LABEL="${3:-dev}"
ARCH_ARG="${4:-$(uname -m)}"

case "$ARCH_ARG" in
  x86_64|amd64)
    ARCH_NAME="x86_64"
    TARGET="x86_64-unknown-linux-gnu"
    ;;
  aarch64|arm64)
    ARCH_NAME="arm64"
    TARGET="aarch64-unknown-linux-gnu"
    ;;
  *)
    ARCH_NAME="$ARCH_ARG"
    TARGET="${ARCH_ARG}-unknown-linux-gnu"
    ;;
esac

mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"

SERVER_STAGE="$OUT_ABS/horizon-server-linux-$ARCH_NAME"
CLIENT_STAGE="$OUT_ABS/horizon-linux-$ARCH_NAME"
rm -rf "$SERVER_STAGE" "$CLIENT_STAGE"
mkdir -p "$SERVER_STAGE" "$CLIENT_STAGE"

cd "$UPSTREAM_DIR"

export HORIZON_VERSION="$VERSION_LABEL"
export RUSTC_WRAPPER=""
export RUSTC_WORKSPACE_WRAPPER=""

echo "==> [1/3] 编译专用服核心引擎 (horizon-game --no-default-features --bin horizon-client)"
cargo build --release --locked \
  -p horizon-game --no-default-features --bin horizon-client

echo "==> [2/3] 编译控制端 (horizon-ctl)、专用服守护 (horizon-server) 与资源准备工具 (horizon-prepare)"
cargo build --release --locked \
  -p horizon-client-lib --bin horizon-ctl \
  -p horizon-server --bin horizon-server \
  -p horizon-prepare --bin horizon-prepare

echo "==> [3/3] 整理产物并按官方规范打包"
# horizon-server-linux-$ARCH_NAME (官方专用服标准包)
cp -f target/release/horizon-client "$SERVER_STAGE/horizon-engine"
cp -f target/release/horizon-ctl "$SERVER_STAGE/horizon-ctl"
cp -f target/release/horizon-server "$SERVER_STAGE/horizon-server"
cp -f target/release/horizon-prepare "$SERVER_STAGE/horizon-prepare"

# horizon-linux-$ARCH_NAME (无头客户端与服务端完整包)
cp -f target/release/horizon-client "$CLIENT_STAGE/horizon-client"
cp -f target/release/horizon-client "$CLIENT_STAGE/horizon-engine"
cp -f target/release/horizon-ctl "$CLIENT_STAGE/horizon-ctl"
cp -f target/release/horizon-server "$CLIENT_STAGE/horizon-server"
cp -f target/release/horizon-prepare "$CLIENT_STAGE/horizon-prepare"

for f in LICENSE THIRD_PARTY_NOTICES.md; do
  [ -f "$f" ] && cp -f "$f" "$SERVER_STAGE/$f" && cp -f "$f" "$CLIENT_STAGE/$f"
done
[ -d LICENSES ] && cp -r LICENSES "$SERVER_STAGE/LICENSES" && cp -r LICENSES "$CLIENT_STAGE/LICENSES"

cat > "$SERVER_STAGE/BUILD_INFO.txt" <<EOF
upstream_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
upstream_date=$(git show -s --format=%cI HEAD 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
target=$TARGET
arch=$ARCH_NAME
version=$VERSION_LABEL
package=horizon-server-linux-$ARCH_NAME
features=dedicated-server (horizon-engine, horizon-server, horizon-ctl, horizon-prepare)
EOF

cp -f "$SERVER_STAGE/BUILD_INFO.txt" "$CLIENT_STAGE/BUILD_INFO.txt"
sed -i "s/package=horizon-server-linux-$ARCH_NAME/package=horizon-linux-$ARCH_NAME/g" "$CLIENT_STAGE/BUILD_INFO.txt"

# 归档压缩为 tar.gz
tar -C "$OUT_ABS" -czf "$OUT_ABS/horizon-server-linux-$ARCH_NAME.tar.gz" "horizon-server-linux-$ARCH_NAME"
tar -C "$OUT_ABS" -czf "$OUT_ABS/horizon-linux-$ARCH_NAME.tar.gz" "horizon-linux-$ARCH_NAME"

# 若为 ARM64，额外保留 horizon-headless-server-linux-arm64.tar.gz 兼容旧版名称
if [[ "$ARCH_NAME" == "arm64" ]]; then
  cp -f "$OUT_ABS/horizon-linux-arm64.tar.gz" "$OUT_ABS/horizon-headless-server-linux-arm64.tar.gz"
fi

rm -rf "$SERVER_STAGE" "$CLIENT_STAGE"

echo "==> 二进制打包完成:"
ls -lh "$OUT_ABS"/*.tar.gz
