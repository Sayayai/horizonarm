#!/usr/bin/env bash
set -euo pipefail

# 用法:
#   ./scripts/fetch-sdk.sh <owner/repo> [release_tag|latest] [dest_dir] [arch]
# 示例:
#   ./scripts/fetch-sdk.sh myorg/horizonarm latest .horizon/sdk x86_64
#   ./scripts/fetch-sdk.sh myorg/horizonarm latest .horizon/sdk aarch64
REPO="${1:?用法: $0 <owner/repo> [release_tag|latest] [dest_dir] [arch]}"
TAG="${2:-latest}"
DEST="${3:-.horizon/sdk}"
ARCH="${4:-$(uname -m)}"

case "$ARCH" in
  x86_64|amd64)
    ARCH_PATTERN="*x86_64-unknown-linux-gnu-server.tar.xz"
    ;;
  aarch64|arm64)
    ARCH_PATTERN="*aarch64-unknown-linux-gnu-server.tar.xz"
    ;;
  *)
    echo "警告: 未知架构 '$ARCH'，默认尝试 aarch64"
    ARCH_PATTERN="*aarch64-unknown-linux-gnu-server.tar.xz"
    ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$DEST/api" "$DEST/prebuilt"

echo "==> 从 GitHub Release 下载 SDK (${REPO} @ ${TAG}, 架构: ${ARCH})"
if command -v gh >/dev/null 2>&1; then
  TAG_ARG=()
  [[ "$TAG" != "latest" ]] && TAG_ARG=("$TAG")

  gh release download "${TAG_ARG[@]}" --repo "$REPO" --dir "$TMP_DIR" \
    --pattern "$ARCH_PATTERN" \
    --pattern 'build-data.tar.xz' \
    --pattern 'api-source.tar.xz' \
    --pattern 'surface.json' \
    --pattern 'sdk.json' \
    --pattern 'SHA256SUMS*' || true
else
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
  [[ "$TAG" != "latest" ]] && API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
  curl -fsSL "$API_URL" | python3 -c '
import json, sys
rel = json.load(sys.stdin)
for a in rel.get("assets", []):
    n = a["name"]
    print(n, a["browser_download_url"])
' | while read -r name url; do
    if [[ "$name" == *"build-data.tar.xz"* || "$name" == *"api-source.tar.xz"* || "$name" == *"surface.json"* || "$name" == *"sdk.json"* || "$name" == *"SHA256SUMS"* || "$name" == $ARCH_PATTERN ]]; then
      echo "  -> 下载 $name"
      curl -fL --retry 3 -o "$TMP_DIR/$name" "$url"
    fi
  done
fi

CHECKSUM_FILE=""
if [[ -f "$TMP_DIR/SHA256SUMS" ]]; then
  CHECKSUM_FILE="$TMP_DIR/SHA256SUMS"
elif [[ -f "$TMP_DIR/SHA256SUMS.txt" ]]; then
  CHECKSUM_FILE="$TMP_DIR/SHA256SUMS.txt"
fi

if [[ -n "$CHECKSUM_FILE" ]]; then
  echo "==> 校验 SHA-256"
  (cd "$TMP_DIR" && sha256sum --ignore-missing -c "$CHECKSUM_FILE")
fi

echo "==> 解压 API 源码到 $DEST/api"
if [[ -f "$TMP_DIR/api-source.tar.xz" ]]; then
  rm -rf "$DEST/api" && mkdir -p "$DEST/api"
  tar -xJf "$TMP_DIR/api-source.tar.xz" -C "$DEST/api"
fi

echo "==> 合并解压预编译 SDK 切片到 $DEST/prebuilt"
rm -rf "$DEST/prebuilt" && mkdir -p "$DEST/prebuilt"
for archive in "$TMP_DIR"/*-server.tar.xz "$TMP_DIR"/build-data.tar.xz; do
  [[ -f "$archive" ]] || continue
  echo "  -> 提取 $(basename "$archive")"
  tar -xJf "$archive" -C "$DEST/prebuilt"
done

# 复制元数据
for meta in surface.json sdk.json; do
  [[ -f "$TMP_DIR/$meta" ]] && cp -f "$TMP_DIR/$meta" "$DEST/"
done

echo "==> 完成！SDK 目录结构："
echo "    - 模组 API 源码: ${DEST}/api"
echo "    - 预编译链接目录: ${DEST}/prebuilt"
echo "    - 在模组 Cargo.toml 中配置："
echo "      horizon-mod-api = { path = \"${DEST}/api/crates/horizon-mod-api\" }"
