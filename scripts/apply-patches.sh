#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/apply-patches.sh <TARGET_REPO_DIR> [PATCHES_DIR]
TARGET_DIR="${1:?missing TARGET_DIR}"
PATCH_DIR_ARG="${2:-patches}"

ROOT_DIR="$(pwd)"
cd "$TARGET_DIR"

PATCH_FILES=()

# 1. 扫描 patches 目录
RESOLVED_PATCH_DIR="$ROOT_DIR/$PATCH_DIR_ARG"
if [ ! -d "$RESOLVED_PATCH_DIR" ] && [ -d "$PATCH_DIR_ARG" ]; then
  RESOLVED_PATCH_DIR="$PATCH_DIR_ARG"
fi

if [ -d "$RESOLVED_PATCH_DIR" ]; then
  while IFS= read -r -d '' f; do
    PATCH_FILES+=("$f")
  done < <(find "$RESOLVED_PATCH_DIR" -maxdepth 1 -name "*.patch" -print0 | sort -z)
fi

# 2. 如果根目录有 printer-fix.patch 且不在列表里，加入
for candidate in "$ROOT_DIR/printer-fix.patch" "$ROOT_DIR/../printer-fix.patch"; do
  if [ -f "$candidate" ]; then
    canonical_cand="$(realpath "$candidate")"
    found=0
    for pf in "${PATCH_FILES[@]:-}"; do
      if [ "$(realpath "$pf")" = "$canonical_cand" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      PATCH_FILES+=("$candidate")
    fi
  fi
done

if [ ${#PATCH_FILES[@]} -eq 0 ]; then
  echo "==> 未发现任何 .patch 补丁文件，保持上游源码不变。"
  exit 0
fi

echo "==> 发现以下自定义补丁，正在按顺序应用："
for patch in "${PATCH_FILES[@]}"; do
  echo "  --> 应用补丁: $(basename "$patch")"
  git apply --verbose "$patch"
done

# 3. 将补丁变动提交到本地 Git 树
# prebuilt_game.py 依赖 git archive HEAD (tracked_blobs) 构建 SDK，提交后可确保 SDK 与二进制完全包含补丁内容
if [ -n "$(git status --porcelain)" ]; then
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add -A
  git commit -m "chore: apply custom downstream patches"
  echo "==> 补丁已提交至本地构建树：$(git rev-parse --short HEAD)"
fi

echo "==> 所有补丁应用完成！"
