#!/usr/bin/env bash
set -euo pipefail

# 用法: scripts/apply-patches.sh [TARGET_REPO_DIR] [PATCHES_DIR]
# 默认: TARGET_REPO_DIR="."，PATCHES_DIR="patches"
TARGET_DIR="${1:-.}"
PATCH_DIR_ARG="${2:-patches}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HORIZONARM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOLVED_TARGET="$(cd "$TARGET_DIR" && pwd)"

# 收集所有候选补丁的绝对路径
RAW_CANDIDATES=()

# 检查可能的 patches 存放目录
CANDIDATE_DIRS=(
  "$PATCH_DIR_ARG"
  "$HORIZONARM_ROOT/$PATCH_DIR_ARG"
  "$HORIZONARM_ROOT/patches"
  "$(pwd)/$PATCH_DIR_ARG"
  "$(pwd)/patches"
)

for pdir in "${CANDIDATE_DIRS[@]}"; do
  if [ -d "$pdir" ]; then
    while IFS= read -r -d '' f; do
      RAW_CANDIDATES+=("$(realpath "$f")")
    done < <(find "$pdir" -maxdepth 1 -type f -name "*.patch" -print0 2>/dev/null | sort -z)
    break
  fi
done

# 兼容根目录下的 printer-fix.patch
for candidate in "$HORIZONARM_ROOT/printer-fix.patch" "$(pwd)/printer-fix.patch"; do
  if [ -f "$candidate" ]; then
    RAW_CANDIDATES+=("$(realpath "$candidate")")
  fi
done

# 按文件名去重（避免 patches/xxx.patch 和 ./xxx.patch 重复应用）
PATCH_FILES=()
SEEN_NAMES=" "
if [ ${#RAW_CANDIDATES[@]} -gt 0 ]; then
  for p in "${RAW_CANDIDATES[@]}"; do
    [ -z "$p" ] && continue
    bname="$(basename "$p")"
    if [[ ! "$SEEN_NAMES" =~ " $bname " ]]; then
      PATCH_FILES+=("$p")
      SEEN_NAMES+="$bname "
    fi
  done
fi

if [ ${#PATCH_FILES[@]} -eq 0 ]; then
  echo "==> 未发现任何 .patch 补丁文件，保持上游源码不变。"
  exit 0
fi

cd "$RESOLVED_TARGET"

echo "==> 发现以下自定义补丁，正在按顺序应用："
for patch in "${PATCH_FILES[@]}"; do
  patch_name="$(basename "$patch")"
  if git apply --check "$patch" >/dev/null 2>&1; then
    echo "  --> 应用补丁: $patch_name"
    git apply --verbose "$patch"
  elif git apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "  --> 补丁 $patch_name 已经应用过，跳过重复应用。"
  else
    echo "::error::补丁 $patch_name 与当前上游代码冲突或无法应用！"
    git apply --verbose "$patch"
  fi
done

# 将补丁变动提交到本地 Git 树
# prebuilt_game.py 依赖 git archive HEAD (tracked_blobs) 构建 SDK，提交后可确保 SDK 与二进制完全包含补丁内容
if [ -n "$(git status --porcelain)" ]; then
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add -A
  git commit -m "chore: apply custom downstream patches"
  echo "==> 补丁已提交至本地构建树：$(git rev-parse --short HEAD)"
else
  echo "==> 工作树干净，无需额外提交。"
fi

echo "==> 所有补丁处理完成！"
