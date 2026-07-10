# CLAUDE.md

このファイルは **このリポジトリ（which-model）を開発するときの規約** です。
which-model skill 自体の動作指示（SKILL.md）とは別物です。

> 注記：README.md 付録の「CLAUDE.md 追記スニペット」は、この skill を導入した*先*の
> プロジェクトでモデルルーティングを常時参照させるための任意スニペットであり、非推奨とされています。
> 本ファイルはそれとは無関係で、このリポジトリ自体を編集する開発規約です。混同しないでください。

## 正本と同期

- `SKILL.md` が正本。リポジトリ側を編集したら、`~/.claude/skills/which-model/SKILL.md`
  へ必ず同期する。同期の手段は2通り：
  - Claude Code が `SKILL.md` を編集したときは、`.claude/settings.json` の PostToolUse hook が
    即時 `cp` で自動同期する（差分確認なし。hook は `jq` に依存する）。
  - エディタ等で手動編集したときは `./install.sh` を実行する（差分があれば表示して確認できる）。

## SKILL.md の整形

- `SKILL.md` には Prettier をかけない。ネスト番号付きリスト（手順7の a〜e）が
  Markdown 整形で壊れるため、`.prettierignore` で除外されている。

## タグ規律（[Official] / [Heuristic]）

- `[Official]` と `[Heuristic]` を混同しない。
- `01_sources_evidence.md` の `source_id` が正。`02`〜`05` が引用する S-id は、
  必ず `01` に定義が存在すること。

## バージョン更新

- version を上げるときは、`SKILL.md` フロントマターの `version` と `last-updated` を
  同時に更新する。

## ドキュメント方針

- ドキュメントは日本語で書く。
- `SKILL.md` に判断材料（判断表の中身）を書かない。判断材料は
  `docs/ai-model-guides/`（レシピ本）を正とする。
