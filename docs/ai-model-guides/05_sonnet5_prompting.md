# 05. Sonnet 5 プロンプティングガイド（Claude Code 用）

Last verified: 2026-07-05
API model string: `claude-sonnet-5`（Claude Code の Anthropic API では `sonnet` エイリアスが Sonnet 5 に解決 — S49）

タグ：`[Official]`（source_id 付き）／`[Heuristic]`（Confidence 付き）

## 1. 公式ポジショニング `[Official]`

- Sonnet ティアで速度と知性の最良の組み合わせ。コーディング・エージェント作業で Opus に迫る品質（S11）。
- Sonnet 4.6 に対する能力向上版で同価格。最大の向上はコーディングとエージェント作業（S12）。
- adaptive thinking が既定 on（4.6 は off だった）。off にするには `thinking:{type:"disabled"}`（S18）。manual extended thinking は 400（S17）。
- effort 既定は high（Claude API / Claude Code）（S7）。
- 価格 $3/$15 per MTok（2026-08-31 まで導入価格 $2/$10）、1M コンテキスト（既定）、最大出力 128k（S15）。
- 新トークナイザで同じテキストが約 30% 多くトークン化される（S42）。
- 初の Sonnet ティアのリアルタイム・サイバーセキュリティ保護あり（S44）。

## 2. このプロジェクトでの最適タスク

- **`[Official]`** コーディング・エージェント作業全般（最大の向上点）（S12）。
- **`[Heuristic]`** 日々の反復実装（主力）、テスト設計、ドキュメント作成、短い調査・要約。 / Confidence: High / Basis: $3/$15 の価格（S15）＋高頻度タスクという性質＋コーディング向上（S12）。

## 3. プロンプティング原則 `[Official]`

- **応答長はタスクの複雑さに合わせる。** 冗長さを抑えたいなら明示（例：「簡潔で焦点を絞った応答を。非本質的な文脈は省き、例は最小限に」）（S38）。
- **字義的・明示的に解釈（特に低 effort）。** 正の例が否定指示より効果的（S39）。
- **浅い推論が見えたら effort を上げる。** プロンプトで回避せず high/xhigh に。低 effort を保つなら「多段推論を要する。慎重に考えてから答えよ」と的を絞る（S40）。
- **既定でエージェント的。** ツールに手を伸ばし自己検証ループを回しやすい。ただし thinking off だとツールに手を伸ばしにくいので、off で使うなら明示的に促す（S41）。
- **進捗更新を既定で高品質に出す。** 「3 ツール毎に要約」等の強制スキャフォールドは外して試す（S45）。

## 4. 良いプロンプトパターン `[Official]`

- 望む簡潔さ・粒度を正の例で示す（否定指示より効く）（S39）。
- high/xhigh/max では max_tokens に余裕を持たせる。予算が厳しいと応答がほぼ thinking で埋まり本文が truncate され `stop_reason:"max_tokens"` になる（S43）。
- max_tokens は新トークナイザ（約 +30%）を見込んで見直す（Sonnet 4.6 向けだと切り詰められうる）（S42）。
- thinking off でツールを使わせたいときはシステムプロンプトで明示的に促す（S41）。

## 5. 悪いパターン（避ける） `[Official]`

- **抽象的な否定指示（「冗長にするな」）** → 正の例に置き換える（S39）。
- **Sonnet 4.6 向けの max_tokens をそのまま流用** → 約 30% 増で truncate されうる（S42）。
- **強制的な進捗要約スキャフォールドの残置** → 既定で高品質更新を出すので外す（S45）。
- **budget_tokens で thinking 制御** → 400。effort を使う（S17）。
- **禁止・高リスクのサイバー話題** → refusal を返しうる（S44）。

## 6. 再利用テンプレート

### 6-1. 実装（通常・反復）

```md
### Fixed instruction
以下を小さな単位で実装し、各単位でテストを通してください。変更は <scope_in> に限り、<scope_out> は
触らないでください。簡潔で焦点を絞った差分にしてください。

### Variables
- <task>{{実装内容}}</task>
- <scope_in>{{変更してよい範囲}}</scope_in>
- <scope_out>{{触ってはいけない範囲}}</scope_out>
（推奨: effort=high。max_tokens は 4.6 向けから見直す。thinking は既定 on のままでよい）

### Output format
- 差分
- 通したテスト
```

### 6-2. テスト設計

```md
### Fixed instruction
以下の対象について、正常系・境界・異常系を列挙してからテストを書いてください。粒度は次の例に合わせて
ください（正の例）: <example_test>。

### Variables
- <target>{{テスト対象}}</target>
- <example_test>{{望む粒度のテスト 1 つ}}</example_test>
```

### 6-3. ドキュメント作成

```md
### Fixed instruction
以下の内容を、指定の読者に向けて書いてください。文体は <style_example> に合わせてください。
簡潔で、非本質的な文脈は省いてください。

### Variables
- <content>{{ドキュメント化する内容}}</content>
- <audience>{{読者と前提知識}}</audience>
- <style_example>{{望む文体のサンプル}}</style_example>
```

## 7. 検証チェックリスト（投げる前に）

- [ ] このタスクは Sonnet 5 で十分か（難所なら Opus 4.8、長時間・端から端まで なら Fable 5）。
- [ ] 簡潔さ・粒度を正の例で示したか（否定指示になっていないか）。（S39）
- [ ] max_tokens を新トークナイザ（+30%）込みで見直したか。（S42）
- [ ] high 以上なら max_tokens に余裕があるか。（S43）
- [ ] 強制進捗スキャフォールドを外したか。（S45）
- [ ] thinking off で使うならツール使用を明示的に促したか。（S41）

## 8. 出典
S7, S11, S12, S15, S17, S18, S38, S39, S40, S41, S42, S43, S44, S45, S49 → `01_sources_evidence.md`
