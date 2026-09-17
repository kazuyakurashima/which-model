# 軸2 価値検証 v3：設計書

作成: 2026-09-09 ／ 状態: **設計のみ（未実装・未実行）**
前提: v2（`.work/axis2-v2/`）は 2026-08-15 に本実行済み・**人間確認 5 件が未投入で INCOMPLETE**。

> **公開範囲は §8 に定める。** 依頼文と回答本文は公開しない（私有リポジトリの内容を含む）。

---

## 0. 2026-09-09 に決めたこと（利用者の決定。設計はこれに従う）

| 論点 | 決定 |
| --- | --- |
| 本体 | **現行モデルでの新規実行（反復 2）** を価値検証の本体にする。8/15 の v2 は第2 judge で自動完了させ、**探索的ベースライン**として併記する |
| 人間確認 | **Codex を第2 judge に置き、人間は両 judge が割れた比較だけ**を盲検で見る |
| Fable 腕 | **`claude-fable-5-1` を明示指定**し、事前プローブで疎通を確認する。通らなければ Fable 5 に落とし、その旨を報告書に明記する |
| 公開 | **報告書＋ハーネスのコード＋停止規則**。依頼文・回答本文は非公開。t06（リポジトリ非依存）だけ全文 |

---

## 1. 問い（事前登録）

> **2026-09 時点の現行モデル（Fable 5.1 / Opus 5 / Sonnet 5）で、which-model が生成した
> プロンプト B は、素の依頼 A より利用者にとって有用か。**

利用者の仮説「モデルが賢くなり、曖昧な指示でも良い出力が出るようになった」は、
この問いに対する**最も強い反証仮説**として扱う。B が A に勝てなければ、軸2の主張は残らない。

**副次（探索的）**：v2（Fable 5 世代・2026-08-15）との方向の比較。同じ 10 タスクだが、
リポジトリの状態もモデルも違うので、**勝敗数の方向を並べて見るだけ**で、差を結論にしない。

**測らないもの**は v2 と同じ：B vs C（モデル固有ガイドの追加価値）、軸1（モデル選定）。

---

## 2. v2 からの差分（これだけ変える。他は v2 の設計を継承する）

| 項目 | v2 | v3 |
| --- | --- | --- |
| 反復 | 1 | **2**（B はプロンプトを反復ごとに再生成。反転を検出できる） |
| seed | 20260815 | **20260909** |
| 回答モデルの指定 | エイリアス（`fable` 等） | **フル ID を明示**：`claude-fable-5-1` / `claude-opus-5` / `claude-sonnet-5`。この経路では `fable` エイリアスが Fable 5 に解決するため（S142）、エイリアス任せにしない |
| 実モデルの記録 | 無し（エイリアス名のみ） | stream-json の `system/init` イベントにある `model` を **`actual_model`** として記録。**指定 ID と不一致なら `status=model_mismatch`（ok にしない）**。8/15 のログでこの値が取れることは確認済み（`"model":"claude-fable-5"`） |
| B 生成の `p model <alias>` | `fable` 等 | **変えない**。これは skill の語彙で、skill 内部で Fable 5.1 のガイドに解決する（8.0.0 受入 8c で確認済み）。生成側と回答側で「Fable」の指す先が食い違わないことを、B プロンプト内の `確定モデル：` 行で機械検査する |
| 人間確認の抽出 | 4 条件（不一致／critical／ツール0回／無作為20%） | **第2 judge との不一致だけ**（§4）。無作為抽出は廃止。ツール0回は「判定失敗」としてリトライ対象にする |
| 停止規則 4 | 人間と judge の食い違い率 | **judge 間（Claude / Codex）の食い違い率**（§5） |
| workdir | `<private-dir-2>/<private-repo-1>` | `<private-dir-1>/<private-repo-1>`（移動済み。8/15 以降のコミットは 1 件） |
| 完了ゲート | run / judge / human | run / **judge / judge2** / human（不一致分のみ） |

継承するもの（再発見しない）：`--bare` 不可、`--allowedTools Read` 必須、B 生成の cwd は空 sandbox、
`is_error` を ok にしない、与えたツールの拒否は失敗、本文 grep でツール使用を判定しない、
コード自体の凍結、冪等、A→B 固定順の廃止、pairwise の左右入替 2 回、盲検 X/Y の別抽選。

---

## 2-2. 実行条件：MCP を無効化する（2026-09-10 追加）

評価用の Claude 呼び出し（プローブ・B 生成・A/B 回答・Claude judge）は
**`--strict-mcp-config` を付け、MCP サーバーを 0 個で走らせる。**

**理由（実測）：** 2026-09-10 のプローブで、`--tools ""` を付けた `claude -p` に
**7 サーバー・145 個の MCP ツール定義が読み込まれ、出力 3 トークンに対して
140,288 トークンの 1 時間キャッシュ書き込みが発生した**（`logs/probe_fable51_*.log`）。
`--tools` は呼べるツールを制限するだけで、定義の読み込みは止めない。

**この扱いの限界（越えないこと）：**

- **「v2 と完全に同条件」とは言わない。** v2 の記録は `mcp_servers=0` だったが、
  当時 MCP が未接続だっただけで、条件を揃える操作をしたわけではない。
  v3 で言えるのは「**MCP を使わない条件に揃えた**」までである。
- **利用者の MCP 設定・接続・認証は変更していない。** 呼び出し単位のフラグである。
- **費用がどれだけ下がるかは未検証。** 「+$170」「合計 $250 超」といった試算は
  未検証の仮定に基づくもので、確定した見積もりとして扱わない。
  実際の量は本実行の最初の少数件で確認する。
- **API 換算額と実際の請求額は別物。** サブスクリプションの枠を消費するもので、
  枠内なら追加請求は発生しない。

## 3. 第2 judge（Codex）

**目的：** 人間の盲検確認を「judge の校正」から「割れたときの決着」へ縮め、人手を減らす。
Claude 系（primary judge）と別系統のモデルが同じ判定に達したかを、校正の代理にする。

| 項目 | 内容 |
| --- | --- |
| 実体 | `codex exec`（codex-cli 0.145.0。認証済み・`OPENAI_API_KEY` 不要） |
| モデル | **`gpt-6-astra`**（`~/.codex/config.toml` の既定と同じ。固定して記録する） |
| 呼び出し | `codex exec --ignore-user-config -m gpt-6-astra -c 'model_reasoning_effort="high"' --sandbox read-only -C <workdir> --skip-git-repo-check --ephemeral --json -o <last-message> --output-schema <judge_schema.json> "<prompt>"` |
| なぜ `--ignore-user-config` | 利用者の config.toml は `notify` で Computer Use クライアントを起動する。判定のたびに起動させない。認証は `CODEX_HOME` から読まれる |
| プロンプト | Claude judge と**同一テンプレート**。ツール名の記述（`Read` / `Grep` / `Glob`）だけ「読み取り専用のシェル」に差し替えた別ファイル `judge_prompt_codex.txt` / `judge_prompt_context_codex.txt` として凍結する |
| 提示順 | `plan.json` の `judge_orders` と**同じ 2 順**（AB / BA） |
| workdir | context_required=true は回答者と同じリポジトリ（`--sandbox read-only`）。false は空 sandbox |
| ツール回数 | `--json` のイベント列から数える。**実形は probe で確定**（§7 手順 1b）。context_required=true で 0 回なら判定失敗としてリトライ（`retry_max`）。それでも 0 なら `unverified` として人間へ |
| 出力 | `judgements2/<unit>_<seq>_<order>.json`。スキーマは `judgements/` と同じ＋ `judge_family: "codex"`, `judge_model: "gpt-6-astra"`。USD が取れない場合はトークン数だけ記録し、コストは「—」 |
| 写像 | `parse_judgement.py` と同じ表（STOP-RULES §1）。**コードを共有し、Codex 用に別の写像を書かない** |

**judge_schema.json**（`--output-schema`）：`verdict` を 5 値の enum、`reason` / `evidence` を string に固定する。
Claude 側は既存どおり本文から最後の JSON を抽出する（変えない）。

---

## 4. 確定規則（人間の手が要る条件を、ここで最小に定める）

比較単位ごとに：

- **J1** … Claude judge の確定勝者（2 順が一致したときだけ確定。それ以外 `unresolved`）
- **J2** … Codex judge の確定勝者（同じ規則）

| 状況 | 確定 |
| --- | --- |
| J1 = J2 ∈ {A, B, tie} | **自動確定**。final = J1 |
| J1 ≠ J2、またはどちらかが `unresolved` | **人間確認へ**（盲検 X/Y。context_required ならリポジトリを開いて照合）。`human/<unit>.json` が final |

**critical error** は規則 3 にだけ効く。**両 judge が同じ腕に報告したときだけ確定**する。
片方だけの報告は「未確定 critical」として REPORT に件数を出すが、規則 3 の集計に入れない。
**critical の食い違いだけでは人間確認へ回さない**（勝者が一致しているなら final は確定する）。

**人間確認の見積**：v2 の 10 単位に Codex を後付け（§6）すると judge 間の一致率が分かる。
それを v3 の 20 単位に当てて見積もる。一致率 75% なら人間確認は 5 単位前後（1 単位 10〜15 分）。
**ここは設計上ゼロにならない。** ゼロにするなら「2 系統の LLM が一致した」以上のことは言えなくなる
（2026-09-09 の決定で、この線は越えないことにした）。

---

## 5. 停止規則 v3（実行前に凍結する。`STOP-RULES.md` はこの節から起こす）

**完了ゲート（先に効く）**：予定 run が全件 `ok`（`actual_model` 一致を含む）／J1 が全件／J2 が全件／
不一致分の人間確認が全件。揃わないうちは **INCOMPLETE / 判定保留**（「価値信号なし」ではない）。

| 規則 | 内容 | v2 からの変更 |
| --- | --- | --- |
| 1 | B勝ちタスク数が 3 件未満 | 同じ |
| 2 | B勝ちタスク数が A勝ちタスク数以下 | 同じ |
| 3 | **確定** critical error が B ≥ 2 かつ B > A | 「確定」＝両 judge 一致、に限定 |
| 4 | **judge 間の食い違い率 > 1/3**（全比較単位のうち J1 ≠ J2 または unresolved を含む単位の割合） | 人間との食い違い → judge 間の食い違い |

規則 4 に該当したときの結論は **「判定不能」**（価値信号なし／あり のどちらも言わない）。
判定装置が信頼できないことと、製品に価値が無いことは別だからである。

**規則 4 の変更で失うもの（明記）**：v2 の規則 4 は人間が judge を校正していた。v3 では人間は
「割れたとき」しか見ないので、**両 judge が同じ誤りをした場合は検出できない**。得るものは、人手を
不一致分に限れること。この取引は 2026-09-09 の決定 2 に基づく。

タスク勝者の規則（反復 2）は v2 STOP-RULES §1 の表をそのまま使う（反転・保留は B勝ちに数えない）。
結論の書き方（率で書かない・「検出できなかった」と書く・モデル別の差を結論にしない・読み取り専用の
範囲でしか言えない）も v2 §3 を継承する。

---

## 6. v2（8/15）の探索的完了

- v2 は凍結済みで、`judgements2/` を足すことは**凍結後の変更**。v2 の `STOP-RULES.md` §4 に
  「2026-09-09：第2 judge を後付け。結果（REPORT.md）を見た後の変更なので**探索的観察**へ格下げ」と
  記録してから行う。manifest は作り直す。
- Codex judge を v2 の 10 単位 × 2 順 ＝ 20 回。§4 の規則で自動確定し、不一致分だけ人間へ。
  v2 の抽出条件（無作為 20%・critical・ツール0回）は使わない。
- 得られるもの：①v2 の結論（探索的ラベル付き）②**judge 間の一致率**（v3 の人間確認量の見積に使う）。
- v2 の回答本文・B プロンプトは引き続き開かない（`BLINDING-LOG.md` §3）。

---

## 7. 自動化：`bin/all.sh`（1 コマンドで人間確認の直前まで進める）

冪等・再開可能。全段の標準出力を `logs/all.log` に落とす。**各段の完了ゲートで止まる。**
このセッションの Claude がバックグラウンドで起動し、進行は**件数と status の集計だけ**を見る
（`BLINDING-LOG.md` §3。回答本文・B プロンプト・判定理由は開かない）。

| 段 | 内容 | 課金 |
| --- | --- | --- |
| 0 | `bin/selftest.sh`：偽 claude ＋ **偽 codex** で全経路（不一致→人間、一致→自動確定、model_mismatch→ゲート停止）を通す | 無料 |
| 1a | **Fable 5.1 プローブ**：空 sandbox で `claude -p --model claude-fable-5-1 --output-format stream-json` を 1 回。`init.model` が `claude-fable-5-1` なら採用。エラー／別 ID なら tasks の Fable 3 件を `claude-fable-5` に落とし、`plan.json` と REPORT に「Fable 腕は 5 で実施」と記録 | 約 $0.05 |
| 1b | **Codex プローブ**：`codex exec --json` を 1 回、ツール使用を含む短い依頼で走らせ、イベントの実形（ツール系イベント名・トークン usage の有無）を確定して `judge2_codex.py` のパーサに反映 | Codex 1 回 |
| 2 | `bin/prepare.sh`：タスク検証（`model_id` の形式・workdir の存在）→ plan → A/B プロンプト（B は 20 本）→ **B 内の `確定モデル：` 行が target と一致するか検査** → 凍結 | B 生成 20 回 ≈ $16 |
| 3 | `bin/run.sh`：40 run。`--model <model_id>`。`actual_model` を記録し不一致は ok にしない | ≈ $32 |
| 4 | `bin/grade-pairwise.sh`：Claude judge 40 回 | ≈ $40 |
| 5 | `bin/grade2-codex.sh`：Codex judge 40 回（段 4 と独立なので**並行して走らせる**） | Codex 40 回 |
| 6 | `bin/analyze.sh`：REPORT.md（INCOMPLETE）＋ `human-review.md`（**不一致分のみ**）＋ `review/<unit>/{X,Y}.md` | 無料 |
| 7 | 人間が `human/<unit>.json` を置く → `bin/analyze.sh` 再実行 → 完了 → `bin/publish.sh` | 無料 |

**v2 の探索的完了**は別コマンド `bin/retro-v2.sh`（§6）。段 1b の後、段 2 と並行して走らせてよい。

**利用者の手が必要な点は 2 つだけ**：①有料段の開始承認（1 回。上限額つき）②段 7 の不一致分の盲検確認。

---

## 8. 公開物（`docs/evaluation/axis2/`。`bin/publish.sh` が許可リストだけから生成する）

| 公開する | 公開しない |
| --- | --- |
| `REPORT.md`（v3 本体。v2 は探索的として付録） | `prompts/`（A は実際の依頼文、B は私有リポジトリの文脈を含む） |
| `DESIGN.md` / `STOP-RULES.md`（凍結版。manifest のハッシュを併記） | `outputs/`（回答本文） |
| `bin/` / `tests/` / `config.json`（ハーネス一式） | `judgements*/` の `reason` / `evidence`（本文引用を含む） |
| `tasks.public.json`：id・`_kind`・target model/effort・context_required・文字数・SHA-256。**t06 だけ `text` 全文** | `review/` / `human/` / `logs/` |
| `judgements.public.csv`：unit・order・verdict・winner_arm・judge_family・tool_calls（理由は落とす） | |

`publish.sh` は生成後に**私有リポジトリのパス・プロジェクト名**を公開物から grep し、ヒットしたら非ゼロ終了する。
README に「価値検証」の節を 1 つ足し、結論を STOP-RULES §3 の書き方でそのまま書く。
**否定的なら否定的と書く。**「自分の見立ても、AIの結論も絶対視しない」の実例として出す。

---

## 9. 費用・時間の見積（v2 実測から）

| 項目 | v2 実測（反復 1） | v3 見積（反復 2） |
| --- | --- | --- |
| B 生成 | $7.7（10 本） | ≈ $16（20 本） |
| 回答 | $15.8（20 run） | ≈ $32（40 run） |
| Claude judge | $20.1（20 回） | ≈ $40（40 回） |
| **合計（API 換算・Max の使用枠）** | **$43.5** | **≈ $88** |
| Codex judge | — | 40 回（v3）＋ 20 回（v2 後付け）＝ **60 回**（Codex の利用枠） |
| 壁時計 | 回答 32 分＋生成 18 分＋判定 ≈ 40 分 | ≈ 3 時間（Codex 判定は Claude 判定と並行） |
| 人間 | 5 件（未実施） | **不一致分のみ。** v2 後付けの一致率で見積を確定（目安 3〜6 単位、計 1 時間弱） |

**上限**：API 換算 **$120** を超える見込みになったら止めて報告する（B 生成のリトライ多発などで膨らむ場合）。

---

## 10. この装置で結論できないこと（v2 §13 を継承し、v3 で増えたものを足す）

- **「製品価値が実証された」とは言えない。** 10 タスク・反復 2 で言えるのは「次の投資に値する」まで。
- **両 judge が同じ誤りをした場合は検出できない**（§5 規則 4 の取引）。
- **Fable 腕が 5 に落ちた場合、skill の筆頭推奨（5.1）は測っていない。**
- **v2 との比較は探索的。** モデルもリポジトリ状態も違う。
- **Codex judge は `gpt-6-astra` 1 版での判定。** 別版で同じ結果になるとは言えない。
- 読み取り専用タスクの範囲でしか言えない。書き込みを伴う実装作業は測っていない。
- 10 タスクのうち 7 件が同一リポジトリ（<private-repo-1>）。**新しい依頼は今回集めていない。**
- モデル別の差を結論にしない（fable 3 / opus 3 / sonnet 4）。

---

## 11. 実装タスク（v2 を複製して差分だけ入れる。標準ライブラリのみ）

1. `.work/axis2-v3/` に v2 の `bin/` `tests/` `config.json` `tasks.json` を複製（`outputs/` 等は空）
2. `tasks.json`：workdir を `<private-dir-1>/…` へ、各タスクに `model_id` を追加。`validate_tasks.py` に形式検査
3. `run.sh` / `record_run.py` / `parse_stream.py`：`--model <model_id>`、`init.model` → `actual_model`、不一致 → `status=model_mismatch`
4. `prepare.sh`：B プロンプト内の `確定モデル：` 行と target の一致検査
5. 新規：`bin/grade2-codex.sh`・`bin/lib/judge2_codex.py`（呼び出し・イベント解析）・`judge_prompt*_codex.txt`・`judge_schema.json`。写像は既存 `parse_judgement.to_arms` を import して共有
6. `analyze.py`：J1/J2 の統合、人間対象＝不一致のみ、規則 3 の「確定 critical」、規則 4 の judge 間食い違い率、完了ゲートに judge2 を追加、REPORT に「judge 間一致率」「未確定 critical」節
7. `gate.py`：`judge2` 段。`freeze.py`：`bin/lib/*.json` を GLOBS に追加
8. `tests/fake-codex.py` と `selftest.sh` の拡張（一致→自動確定／不一致→人間／model_mismatch→停止／`確定モデル：` 不一致→停止）
9. `bin/probe-models.sh`（§7 段 1a・1b）、`bin/all.sh`、`bin/retro-v2.sh`、`bin/publish.sh`
10. `STOP-RULES.md` を §5 から起こし、`selftest` 合格後・本実行前に凍結

**実装は無料。** 有料段（§7 の 1a 以降）は利用者の承認を得てから開始する（v2 DESIGN §14 を継承）。
