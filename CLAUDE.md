# CLAUDE.md

このファイルは **このリポジトリ（which-model）を開発するときの規約** です。
which-model skill 自体の動作指示（SKILL.md）とは別物です。

> 注記：README.md 付録の「CLAUDE.md 追記スニペット」は、この skill を導入した*先*の
> プロジェクトでモデル選定ガイドを常時参照させるための任意スニペットであり、非推奨とされています。
> 本ファイルはそれとは無関係で、このリポジトリ自体を編集する開発規約です。混同しないでください。

## 構成（4.0.0：プラグイン配布）

このリポジトリは、Claude プラグインであり、かつ自前 marketplace でもある。

- `.claude-plugin/plugin.json` … プラグイン定義（`version` の正本はここ）。
- `.claude-plugin/marketplace.json` … 自前 marketplace（`which-model@kazuyakurashima`）。
- `skills/pick/SKILL.md` … skill 本体（正本）。呼び出し名は `/which-model:pick`。
- `skills/pick/references/ai-model-guides/` … レシピ本の**同梱コピー**（配布用）。
- `docs/ai-model-guides/` … レシピ本の**正本**（人が編集するのはこちら）。

## 正本と同期

- レシピ本の正本は `docs/ai-model-guides/`。**編集したら必ず `./tools/sync-bundled-guides.sh`
  を実行**し、同梱コピー（`skills/pick/references/ai-model-guides/`）へ反映する。ズレ検出は
  `./tools/sync-bundled-guides.sh --check`（コミット前チェック用）。
- **台帳とガイドの整合は `python3 tools/check-ledger-consistency.py` で機械検査する。**
  ダングリング参照・Retired 参照・「8. 出典」欄の一致（＝エラー）と、モデル別ガイドが引く S-id の
  「対象」欄の整合（＝警告。他モデル参照が正当な場合もあるので人が判断する）を見る。
  **5.0.0 の監査で「上流の台帳を直したのに下流のガイドが追随していない」抜けを繰り返し出したため
  導入した。** モデル世代を更新するときは必ず通す。
- skill 本体の開発ループは `claude --plugin-dir .`（インストール不要でその場のプラグインを読む）。
- **旧 standalone 版の同期 hook（`.claude/settings.json`）は 4.0.0 で削除済み**（ルート `SKILL.md`
  を監視する死んだ hook だった）。`install.sh` は壊れた実行体をやめ、移行案内を表示して終了する
  だけの無害なスクリプトにした（standalone を使うなら `git checkout v3.9.0`）。

## SKILL.md の整形

- `SKILL.md` には Prettier をかけない。ネスト番号付きリスト（手順7の a〜e）が
  Markdown 整形で壊れるため、`.prettierignore` で除外されている。

## タグ規律（[Official] / [Heuristic]）

- `[Official]` と `[Heuristic]` を混同しない。
- `01_sources_evidence.md` の `source_id` が正。`02`〜`05` が引用する S-id は、
  必ず `01` に定義が存在すること。

## バージョン更新

- version の正本は `.claude-plugin/plugin.json` の `version`。上げるときは、`skills/pick/SKILL.md`
  フロントマターの `metadata.version` と `last-updated` も同時に合わせる（複数箇所で食い違わせない）。
- marketplace エントリには `version` を書かない（plugin.json が常に優先され、紛れるため）。

## ドキュメント方針

- ドキュメントは日本語で書く。
- `SKILL.md` に判断材料（判断表の中身）を書かない。判断材料は
  `docs/ai-model-guides/`（レシピ本）を正とする。
- `SKILL.md` には**実行時の指示だけ**を置く。保守規約（この種の取り決め）は本ファイルに置き、
  `SKILL.md` に重複させない。`SKILL.md` は起動のたびに全文がコンテキストに載るため、
  実行時に効かない記述はトークンの浪費であり、過剰指示は指示追従をかえって弱める（S26）。
- 同じ規則を絶対規則と「やらないこと」の両方に書かない。重複は削る。
