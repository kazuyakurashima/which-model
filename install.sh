#!/usr/bin/env bash
# model-router: SKILL.md をユーザーの skill ディレクトリへ同期する。
# このリポジトリの SKILL.md が正本。~/.claude/skills/ 側は常にコピー。
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/SKILL.md"
DEST_DIR="${HOME}/.claude/skills/model-router"
DEST="${DEST_DIR}/SKILL.md"

mkdir -p "$DEST_DIR"

if [[ -f "$DEST" ]] && ! diff -q "$SRC" "$DEST" >/dev/null; then
  echo "既存の $DEST とリポジトリ版に差分があります:"
  diff -u "$DEST" "$SRC" || true
  read -r -p "リポジトリ版で上書きしますか? [y/N] " ans
  [[ "$ans" == "y" ]] || { echo "中止しました。"; exit 1; }
fi

cp "$SRC" "$DEST"
echo "インストール完了: $DEST"
