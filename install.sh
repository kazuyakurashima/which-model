#!/usr/bin/env bash
# which-model は 4.0.0 でプラグイン配布へ移行しました。
# このスクリプト（旧 standalone 版セットアップ）は 4.0.0 では何も変更しません。
# 移行案内を表示して終了します。
set -euo pipefail

cat <<'MSG'
which-model 4.0.0 はプラグインとして配布されています。

  導入：   /plugin marketplace add kazuyakurashima/which-model
           /plugin install which-model@kazuyakurashima
  呼び出し： /which-model:pick <やりたいこと>

判断材料（レシピ本）はプラグインに同梱されているため、プロジェクトへのコピーは不要です。
プロジェクト独自に調整したい場合のみ、docs/ai-model-guides/ を置けばそちらが優先されます。

旧 standalone 版（/which-model、~/.claude/skills/ へコピーする方式）を使いたい場合は
v3.9.0 を使ってください：

  git checkout v3.9.0
  ./install.sh <導入先プロジェクトのパス>

このスクリプトは 4.0.0 では何も変更しません。
MSG

exit 0
