# 軸2 v3 集計結果

> **公開版の注記（2026-09-17）**
> これは**未完了の機械集計**である（状態：INCOMPLETE）。判定者の意見が割れた組の人間確認を行わずに実験を閉じたため、
> 下の勝敗や停止規則の「該当」は結論ではない。終了の判断・理由・限界は
> [CLOSING-2026-09-17.md](CLOSING-2026-09-17.md) を参照すること。
> 盲検が崩れうる2組の扱いと、§6 の「Claude（?）」の実際のモデルもそこに書いてある。
> この注記より下は、集計コード（`bin/lib/analyze.py`）の出力のまま変えていない。

**状態：INCOMPLETE / 判定保留**

タスク 10 件 ／ 反復 2 ／ run 40（成功 40） ／ 判定 Claude 40 ・ Codex 40

> 統計検定は使っていない（標本が少なすぎる）。数え上げだけを見ること。
> **同一タスクの反復を独立タスクとして数えていない。**

## 1. タスク単位の勝敗

| タスク | 反復ごとの勝者 | タスクの勝者 |
| --- | --- | --- |
| t01_teacher_account_setup | unresolved / unresolved | **pending** |
| t02_teacher_line_message | unresolved / A | **pending** |
| t03_admin_displayname_testaccounts | B / unresolved | **pending** |
| t04_docs_findability | unresolved / A | **pending** |
| t05_docs_grouping | unresolved / A | **pending** |
| t06_post_strategy_review | unresolved / unresolved | **pending** |
| t07_anon_key_role | A / unresolved | **pending** |
| t08_jwt_role_design | unresolved / A | **pending** |
| t09_grant_defaults | A / A | **A** |
| t10_doc_jargon_balance | unresolved / A | **pending** |

**B勝ち 0 ／ A勝ち 1 ／ 引き分け 0 ／ 反転 0 ／ 保留 9**

## 2. judge 間の一致（Claude / Codex）

**2系統が同じ勝者を指した比較単位は自動確定**し、割れた分だけ人間が盲検で見る（DESIGN.md §4）。

| | 件数 |
| --- | ---: |
| 両系統の判定が揃った比較単位 | 20 |
| うち一致（自動確定） | 9 |
| うち不一致（人間確認へ） | 11 |
| 一致率 | 45% |

不一致の内訳：

- `t01_teacher_account_setup_r1` … Claude: B（2判定が一致） ／ Codex: unresolved（左右入替で不一致: ['A', 'tie']）
- `t01_teacher_account_setup_r2` … Claude: B（2判定が一致） ／ Codex: tie（2判定が一致）
- `t02_teacher_line_message_r1` … Claude: unresolved（左右入替で不一致: ['B', 'A']） ／ Codex: unresolved（左右入替で不一致: ['tie', 'A']）
- `t03_admin_displayname_testaccounts_r2` … Claude: B（2判定が一致） ／ Codex: A（2判定が一致）
- `t04_docs_findability_r1` … Claude: A（2判定が一致） ／ Codex: B（2判定が一致）
- `t05_docs_grouping_r1` … Claude: B（2判定が一致） ／ Codex: tie（2判定が一致）
- `t06_post_strategy_review_r1` … Claude: unresolved（左右入替で不一致: ['B', 'A']） ／ Codex: unresolved（左右入替で不一致: ['A', 'B']）
- `t06_post_strategy_review_r2` … Claude: A（2判定が一致） ／ Codex: B（2判定が一致）
- `t07_anon_key_role_r2` … Claude: B（2判定が一致） ／ Codex: tie（2判定が一致）
- `t08_jwt_role_design_r1` … Claude: A（2判定が一致） ／ Codex: tie（2判定が一致）
- `t10_doc_jargon_balance_r1` … Claude: B（2判定が一致） ／ Codex: A（2判定が一致）

## 3. critical error

**両系統が同じ腕に報告したものだけを「確定」とし、停止規則3に使う。**

| 腕 | 確定 | 片方だけ（未確定） |
| --- | ---: | ---: |
| A（素の依頼） | 0 | 1 |
| B（which-model） | 2 | 3 |

## 4. judge が実装を確認したか

`context_required=true` の判定は、回答者と同じ workdir と読み取り専用の道具で行う。
**ツール使用0回の判定は採用せずリトライさせている**（判定失敗扱い）ので、ここに残るものは装置の異常である。

- 対象の比較単位: 18 件
- Claude 側でツール0回を含む: 0 件
- Codex 側でツール0回を含む: 0 件

## 5. 実際に使われたモデル

エイリアスは経路によって別世代へ解決するため（S142）、`--model` にフル ID を渡し、
応答の `system/init` に出た実モデル ID と突き合わせている。**不一致は成功扱いにしない。**

| タスク | 指定 | 実測 | 件数 |
| --- | --- | --- | ---: |
| t01_teacher_account_setup | claude-sonnet-5 | claude-sonnet-5 | 4 |
| t02_teacher_line_message | claude-sonnet-5 | claude-sonnet-5 | 4 |
| t03_admin_displayname_testaccounts | claude-sonnet-5 | claude-sonnet-5 | 4 |
| t04_docs_findability | claude-opus-5 | claude-opus-5 | 4 |
| t05_docs_grouping | claude-opus-5 | claude-opus-5 | 4 |
| t06_post_strategy_review | claude-opus-5 | claude-opus-5 | 4 |
| t07_anon_key_role | claude-fable-5-1 | claude-fable-5-1 | 4 |
| t08_jwt_role_design | claude-fable-5-1 | claude-fable-5-1 | 4 |
| t09_grant_defaults | claude-fable-5-1 | claude-fable-5-1 | 4 |
| t10_doc_jargon_balance | claude-sonnet-5 | claude-sonnet-5 | 4 |

## 6. コスト・時間・ツール（成功 run のみ）

B の合計には **which-model のプロンプト生成費用を含む**（DESIGN.md §9）。

| 腕 | run | 回答$ | 生成$ | 合計$ | 合計時間s | 出力文字 | ツール |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 20 | 4.950 | — | 4.950 | 1047.2 | 24768 | 95 |
| B | 20 | 9.187 | 15.755 | 24.942 | 3010.8 | 46898 | 182 |

B − A ： コスト 19.992 USD ／ 時間 1963.6 s

judge のコスト：
- Claude（?）: 16.313 USD ／ 40 回
- Codex: — USD ／ 40 回（サブスクリプション枠。USD が取れない場合は —）

> コストは停止規則に入れない（記録・報告のみ）。

## 7. 人間確認（盲検・不一致分のみ）

- 抽出: 11 件 → `human-review.md`
- 確認済み: 0 件

## 8. 停止規則の評価

規則は実行前に凍結してある（`STOP-RULES.md`）。

| 規則 | 該当 | 実測 |
| --- | --- | --- |
| 1. B勝ちタスク数が3件未満 | **該当** | B勝ち 0 件 |
| 2. B勝ち数が A勝ち数以下 | **該当** | B 0 / A 1 |
| 3. B だけに確定した重大な正確性低下が複数（B≥2 かつ B>A） | **該当** | 確定 critical error B 2 / A 0 |
| 4. judge 間の食い違い率が 1/3 超（→ 判定不能） | **該当** | 20 単位中 不一致 11 件（55%） |

### 判定：**INCOMPLETE / 判定保留**

**完了ゲートを満たしていないため、停止規則を適用しない。**
上の表は参考値であって、「価値信号なし」ではない。

- 未完了: judge 間の不一致 11 件が未確認（`human-review.md`）

同じコマンドを再実行すれば欠けた分だけ埋まる（冪等）。**装置の失敗を製品の評価に化けさせないこと。**

## 9. 書き方の制約

- 「差がなかった」ではなく「この規模では差を検出できなかった」と書く
- 勝敗は率（%）でなく件数で書く
- タスクが8件に満たない場合はその旨を併記する（今回 10 件）
- **モデル別の差を結論にしない。** 構成は claude-fable-5-1 3件／claude-opus-5 3件／claude-sonnet-5 4件 で、モデルごとの比較に耐える数ではない
- 読み取り専用タスクの範囲でしか言えない
- **両 judge が同じ誤りをした場合は検出できない**（DESIGN.md §5 の取引）
