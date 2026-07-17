#!/usr/bin/env bash
# which-model は 4.0.0 でプラグイン配布へ移行しました。
# このスクリプト（旧 standalone 版セットアップ）は 4.0.0 では何も変更しません。
# 移行案内を表示して終了します。
set -euo pipefail

cat <<'MSG'
which-model 4.0.0 はプラグインとして配布されています。

  導入：   /plugin marketplace add kazuyakurashima/which-model
           /plugin install which-model@kazuyakurashima
           インストール後、Claude Code 内で /reload-plugins を実行してください。
           認識されない場合は新しいセッションを開くか、Claude Code を再起動してください。
  呼び出し： /which-model:pick <やりたいこと>

判断材料（レシピ本）はプラグインに同梱されており、プロジェクトへのコピーは不要です。
4.0.0 では、プロジェクト側に docs/ai-model-guides/ を置いても読み込まれません（同梱版のみを使います）。

旧 standalone 版（/which-model、~/.claude/skills/ へコピーする方式）を使いたい場合は
v3.9.0 を使ってください：

  git checkout v3.9.0
  ./install.sh <導入先プロジェクトのパス>

このスクリプトは 4.0.0 では何も変更しません。
MSG

exit 0
