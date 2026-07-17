#!/usr/bin/env bash
# レシピ本の正本（docs/ai-model-guides/）を、プラグイン同梱コピー
# （skills/pick/references/ai-model-guides/）へ同期する。
#
# 正本は docs/ai-model-guides/（CLAUDE.md 参照）。同梱コピーはマーケット配布時に
# プラグインへ含めるための複製で、正本を編集したら必ずこれを実行して一致させる。
#
#   ./tools/sync-bundled-guides.sh          # 同期する
#   ./tools/sync-bundled-guides.sh --check  # 一致していなければ非ゼロで終了（CI/コミット前チェック用）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO_DIR}/docs/ai-model-guides"
DEST="${REPO_DIR}/skills/pick/references/ai-model-guides"

if [[ "${1:-}" == "--check" ]]; then
  if diff -rq "$SRC" "$DEST" >/dev/null 2>&1; then
    echo "同梱レシピ本は正本と一致しています。"
    exit 0
  else
    echo "ズレ検出：docs/ai-model-guides/ と skills/pick/references/ai-model-guides/ が一致しません。" >&2
    echo "  ./tools/sync-bundled-guides.sh を実行して同期してください。" >&2
    diff -rq "$SRC" "$DEST" || true
    exit 1
  fi
fi

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$SRC" "$DEST"
echo "同期しました: docs/ai-model-guides/ → skills/pick/references/ai-model-guides/"
