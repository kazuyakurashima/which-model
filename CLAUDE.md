# CLAUDE.md

このファイルは **このリポジトリ（which-model）を開発するときの規約** です。
which-model skill 自体の動作指示（SKILL.md）とは別物です。

> 注記：README.md 付録の「CLAUDE.md 追記スニペット」は、この skill を導入した*先*の
> プロジェクトでモデル選定ガイドを常時参照させるための任意スニペットであり、非推奨とされています。
> 本ファイルはそれとは無関係で、このリポジトリ自体を編集する開発規約です。混同しないでください。

## 構成（プラグイン配布）

このリポジトリは、自前 marketplace であり、その中に配布物としてのプラグインを持つ。

- `.claude-plugin/marketplace.json` … 自前 marketplace（`which-model@kazuyakurashima`）。
  `source` は `./plugins/which-model`。
- `plugins/which-model/` … **配布される単位はここだけ**（プラグインルート）。
  - `.claude-plugin/plugin.json` … プラグイン定義（`version` の正本はここ）。
  - `skills/pick/SKILL.md` … skill 本体（正本）。呼び出し名は `/which-model:pick`。
  - `skills/pick/references/ai-model-guides/` … レシピ本の**同梱コピー**（配布用）。
  - `LICENSE` … ルートの `LICENSE` と**バイト同一のコピー**。Apache-2.0 §4(a) が再頒布物への
    同梱を求めるため、配布単位であるここにも置く。編集はルート側だけを直し、必ず複製し直す。
  - `README.md` … 配布用のスタブ（説明・呼び出し名・正本リンクのみ）。リポジトリの `README.md`
    と二重保守しないため、内容を増やさない。
- `docs/ai-model-guides/` … レシピ本の**正本**（人が編集するのはこちら）。**配布されない。**

**リポジトリルートに置いたものは配布されない**（`CLAUDE.md`・`docs/`・`tools/`・`tests/`・
`install.sh`）。5.1.0 より前は `source` が `./` でリポジトリ全体が配布されており、レシピ本が
二重に配られ `CLAUDE.md` まで同梱されていた。**配布物を増やしたいとき以外、`plugins/which-model/`
にファイルを足さない。**

## 正本と同期

- レシピ本の正本は `docs/ai-model-guides/`。**編集したら必ず `./tools/sync-bundled-guides.sh`
  を実行**し、同梱コピー（`plugins/which-model/skills/pick/references/ai-model-guides/`）へ
  反映する。ズレ検出は
  `./tools/sync-bundled-guides.sh --check`（コミット前チェック用）。
- **台帳とガイドの整合は `python3 tools/check-ledger-consistency.py` で機械検査する。**
  ダングリング参照・Retired 参照・「8. 出典」欄の一致（＝エラー）と、モデル別ガイドが引く S-id の
  「対象」欄の整合（＝警告。他モデル参照が正当な場合もあるので人が判断する）を見る。
  **5.0.0 の監査で「上流の台帳を直したのに下流のガイドが追随していない」抜けを繰り返し出したため
  導入した。** モデル世代を更新するときは必ず通す。
- skill 本体の開発ループは `claude --plugin-dir ./plugins/which-model`（インストール不要で
  その場のプラグインを読む）。**リポジトリルートを渡しても読めない**（プラグインルートは
  `plugins/which-model/` に移った）。
- **旧 standalone 版の同期 hook（`.claude/settings.json`）は 4.0.0 で削除済み**（ルート `SKILL.md`
  を監視する死んだ hook だった）。`install.sh` は壊れた実行体をやめ、移行案内を表示して終了する
  だけの無害なスクリプトにした（standalone を使うなら `git checkout v3.9.0`）。

## リリース前の検証（2本とも通す）

```sh
claude plugin validate . --strict                      # marketplace 側
claude plugin validate ./plugins/which-model --strict   # プラグイン側
```

**検査範囲が違うので片方では足りない。** marketplace 側の検証は marketplace manifest と
`source` 先の `plugin.json` を検査する（ネストした `plugin.json` の `version` を数値にすると
`plugins[0] plugin.json → version: Invalid input` で落ちることを実測）。一方 `SKILL.md` など
コンポーネント本体は検査しないため（フロントマターを壊しても marketplace 側は合格する）、
プラグインディレクトリを別途検証する。審査パイプラインも提出物に同じ検査を走らせる。

## SKILL.md の整形

- `SKILL.md` には Prettier をかけない。ネスト番号付きリスト（手順9・10 などの a〜f）が
  Markdown 整形で壊れるため、`.prettierignore` で除外されている。

## タグ規律（[Official] / [Heuristic]）

- `[Official]` と `[Heuristic]` を混同しない。
- `01_sources_evidence.md` の `source_id` が正。`02`〜`05` が引用する S-id は、
  必ず `01` に定義が存在すること。

## バージョン更新

- version の正本は `plugins/which-model/.claude-plugin/plugin.json` の `version`。上げるときは、
  `plugins/which-model/skills/pick/SKILL.md` フロントマターの `metadata.version` と
  `last-updated` も同時に合わせる（複数箇所で食い違わせない）。
- marketplace エントリには `version` を書かない（plugin.json が常に優先され、紛れるため）。

## ドキュメント方針

- ドキュメントは日本語で書く。
- `SKILL.md` に判断材料（判断表の中身）を書かない。判断材料は
  `docs/ai-model-guides/`（レシピ本）を正とする。
- `SKILL.md` には**実行時の指示だけ**を置く。保守規約（この種の取り決め）は本ファイルに置き、
  `SKILL.md` に重複させない。`SKILL.md` は起動のたびに全文がコンテキストに載るため、
  実行時に効かない記述はトークンの浪費であり、過剰指示は指示追従をかえって弱める（S26）。
- 同じ規則を絶対規則と「やらないこと」の両方に書かない。重複は削る。
