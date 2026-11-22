#!/usr/bin/env bash
set -euo pipefail

# 用法:
#   ./scripts/fetch-sdk.sh <owner/repo> [release_tag|latest] [dest_dir]
# 示例:
#   ./scripts/fetch-sdk.sh saya/horizon-arm64-headless latest .horizon/sdk
REPO="${1:?用法: $0 <owner/repo> [release_tag|latest] [dest_dir]}"
TAG="${2:-latest}"
DEST="${3:-.horizon/sdk}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$DEST/api" "$DEST/prebuilt"

echo "==> 从 GitHub Release 下载 SDK (${REPO} @ ${TAG})"
if command -v gh >/dev/null 2>&1; then
  if [[ "$TAG" == "latest" ]]; then
    gh release download --repo "$REPO" --dir "$TMP_DIR" \
      --pattern '*aarch64-unknown-linux-gnu-server.tar.xz' \
      --pattern 'build-data.tar.xz' \
      --pattern 'api-source.tar.xz' \
      --pattern 'SHA256SUMS.txt'
  else
    gh release download "$TAG" --repo "$REPO" --dir "$TMP_DIR" \
      --pattern '*aarch64-unknown-linux-gnu-server.tar.xz' \
      --pattern 'build-data.tar.xz' \
      --pattern 'api-source.tar.xz' \
      --pattern 'SHA256SUMS.txt'
  fi
else
  API_URL="https://api.github.com/repos/${REPO}/releases/${TAG}"
  [[ "$TAG" != "latest" ]] && API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
  curl -fsSL "$API_URL" | python3 -c '
import json, sys
rel = json.load(sys.stdin)
for a in rel.get("assets", []):
    n = a["name"]
    if n in ("build-data.tar.xz", "api-source.tar.xz", "SHA256SUMS.txt") or n.endswith("aarch64-unknown-linux-gnu-server.tar.xz"):
        print(n, a["browser_download_url"])
' | while read -r name url; do
    echo "  -> 下载 $name"
    curl -fL --retry 3 -o "$TMP_DIR/$name" "$url"
  done
fi

if [[ -f "$TMP_DIR/SHA256SUMS.txt" ]]; then
  echo "==> 校验 SHA-256"
  (cd "$TMP_DIR" && sha256sum --ignore-missing -c SHA256SUMS.txt)
fi

echo "==> 解压 API 源码到 $DEST/api"
if [[ -f "$TMP_DIR/api-source.tar.xz" ]]; then
  rm -rf "$DEST/api" && mkdir -p "$DEST/api"
  tar -xJf "$TMP_DIR/api-source.tar.xz" -C "$DEST/api"
fi

echo "==> 合并解压预编译 SDK 切片到 $DEST/prebuilt"
rm -rf "$DEST/prebuilt" && mkdir -p "$DEST/prebuilt"
for archive in "$TMP_DIR"/*aarch64-unknown-linux-gnu-server.tar.xz "$TMP_DIR"/build-data.tar.xz; do
  [[ -f "$archive" ]] || continue
  tar -xJf "$archive" -C "$DEST/prebuilt"
done

echo "==> 完成！在模组 Cargo.toml 中配置："
echo "    horizon-mod-api = { path = \"${DEST}/api/crates/horizon-mod-api\" }"
echo "    预编译链接目录位于: ${DEST}/prebuilt"
