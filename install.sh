#!/usr/bin/env bash
# 【旧 standalone 版（v3.9.0 まで）向け・レガシー】
# 4.0.0 以降はプラグイン配布（/plugin marketplace add kazuyakurashima/which-model）が正。
# このスクリプトはルート SKILL.md を前提とするが、4.0.0 でそれは skills/pick/SKILL.md へ
# 移設されたため、そのままでは動かない。standalone 版を使い続ける人のために残置している。
#
# which-model セットアップスクリプト。
# 1) 料理人（SKILL.md）を ~/.claude/skills/which-model/ へ同期する（常に実行）。
# 2) 第1引数に導入先プロジェクトを渡すと、レシピ本（docs/ai-model-guides/）も
#    そのプロジェクトへコピーする（省略時は SKILL.md 同期のみ）。
# このリポジトリの SKILL.md / docs/ai-model-guides/ が正本。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/SKILL.md"
SRC_RECIPE="${SCRIPT_DIR}/docs/ai-model-guides"
DEST_DIR="${HOME}/.claude/skills/which-model"
DEST="${DEST_DIR}/SKILL.md"

TARGET="${1:-}"

# --- 1) 料理人（SKILL.md）の同期（従来どおり・後方互換） ---
mkdir -p "$DEST_DIR"

if [[ -f "$DEST" ]] && ! diff -q "$SRC" "$DEST" >/dev/null; then
  echo "既存の $DEST とリポジトリ版に差分があります:"
  diff -u "$DEST" "$SRC" || true
  read -r -p "リポジトリ版で上書きしますか? [y/N] " ans
  [[ "$ans" == "y" ]] || { echo "中止しました。"; exit 1; }
fi

cp "$SRC" "$DEST"
echo "インストール完了: $DEST"

# --- 2) レシピ本（docs/ai-model-guides/）のコピー（引数があるときだけ） ---
if [[ -z "$TARGET" ]]; then
  echo "ヒント: レシピ本も導入するには ./install.sh <導入先プロジェクト> を実行してください。"
  exit 0
fi

if [[ ! -d "$TARGET" ]]; then
  echo "エラー: 指定した導入先プロジェクトが見つかりません: $TARGET" >&2
  exit 1
fi

DEST_RECIPE="${TARGET%/}/docs/ai-model-guides"

if [[ -d "$DEST_RECIPE" ]]; then
  if diff -ru "$DEST_RECIPE" "$SRC_RECIPE" >/dev/null 2>&1; then
    echo "レシピ本は最新です（変更なし）: $DEST_RECIPE"
  else
    echo "既存のレシピ本 $DEST_RECIPE とリポジトリ版に差分があります:"
    diff -ru "$DEST_RECIPE" "$SRC_RECIPE" || true
    read -r -p "リポジトリ版で上書きしますか? [y/N] " rans
    if [[ "$rans" == "y" ]]; then
      cp -R "$SRC_RECIPE/." "$DEST_RECIPE/"
      echo "レシピ本を更新しました: $DEST_RECIPE"
    else
      echo "レシピ本の更新を中止しました。"
    fi
  fi
else
  mkdir -p "$(dirname "$DEST_RECIPE")"
  cp -R "$SRC_RECIPE" "$DEST_RECIPE"
  echo "レシピ本をコピーしました: $DEST_RECIPE"
fi
