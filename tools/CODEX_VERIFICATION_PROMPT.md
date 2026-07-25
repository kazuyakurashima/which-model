# Codex 独立検証プロンプト（which-model 知識ベース用）

以下の本文を Codex にそのまま渡す。目的は、`docs/ai-model-guides/` の知識ベースを、
Claude とは独立した「別の目」で、Anthropic 公式ドキュメントに照らして検証させること。

---

## Codex に渡す本文（ここから）

あなたは技術ドキュメントの事実検証を行う独立監査者です。この作業は Claude が一度検証済みの
成果物を、別のツールで再検証するものです。Claude の判断を追認せず、公式一次情報だけを根拠に
独立して判定してください。

### 検証対象

リポジトリ `docs/ai-model-guides/` 配下の 6 ファイル：

- `00_index.md` … 全体の使い方
- `01_sources_evidence.md` … **根拠台帳**。全 `[Official]` 記述の source_id（S1〜S106。欠番：S4, S5, S52, S53。Retired：S1, S7, S49）と公式出典（P1〜P21。欠番：P10）の対応表。ここが正の起点。
- `02_model_selection_matrix.md` … タスク×モデル×effort の判断表
- `03_fable5_prompting.md` / `04_opus5_prompting.md` / `05_sonnet5_prompting.md` … モデル別プロンプティングガイド

（補助として、リポジトリ README.md 末尾の CLAUDE.md 追記スニペットも同じタグ規律に従う。）

この知識ベースは 2 層構造で、各記述に必ずタグが付く：
- `[Official]` … Anthropic 公式で確認できる事実。必ず `01` の source_id に紐づく。
- `[Heuristic]` … プロジェクト固有の運用仮説。公式裏付けなし。Confidence 付き。

対象モデルは Claude Fable 5 / **Opus 5** / Sonnet 5 の 3 つ（いずれも 2026 年のモデル。
Opus 5 は 2026-07-24 リリース。あなたの学習データより新しい可能性が高いが、実在する）。
**Opus 4.8 は選定対象から外れたが公式には Active** で、フォールバック先・移行元・互換性の
文脈では台帳に残っている（対象欄に「選定対象外・参照用」と明記されている主張がそれ）。
「4.8 の記述が残っているのは誤り」と早合点しないこと。

### 公式一次情報（`01` の P1〜P21。P10 は欠番・未参照。ここだけを事実の根拠にする）

- P1  Models overview — https://platform.claude.com/docs/en/about-claude/models/overview
- P2  Choosing the right model — https://platform.claude.com/docs/en/about-claude/models/choosing-a-model
- P3  Introducing Claude Fable 5 and Claude Mythos 5 — https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5
- P4  What's new in Claude Opus 4.8（選定対象外・参照用） — https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8
- P5  What's new in Claude Sonnet 5 — https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5
- P6  Prompting best practices — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- P7  Prompting Claude Fable 5 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- P8  Prompting Claude Opus 4.8（選定対象外・参照用） — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8
- P9  Prompting Claude Sonnet 5 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5
- P10 〈欠番・未参照。どの source_id からも参照されない（`01` の「欠番について」参照）〉
- P11 Model configuration (Claude Code) — https://code.claude.com/docs/en/model-config
- P12 Migration guide — https://platform.claude.com/docs/en/about-claude/models/migration-guide
- P13 Effort — https://platform.claude.com/docs/en/build-with-claude/effort
- P14 Refusals and fallback — https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback
- P15 Choosing a Claude model and effort level in Claude Code（公式ブログ、2026-07-07 公開） — https://claude.com/blog/claude-model-and-effort-level-in-claude-code
- P16 What's new in Claude Opus 5 — https://platform.claude.com/docs/en/about-claude/models/whats-new-opus-5
- P17 Prompting Claude Opus 5 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
- P18 Model deprecations — https://platform.claude.com/docs/en/about-claude/model-deprecations
- P19 Fast mode — https://platform.claude.com/docs/en/build-with-claude/fast-mode
- P20 API and data retention — https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
- P21 Claude Fable 5 on your plan（Anthropic 公式サポート記事） — https://support.claude.com/en/articles/15424964-claude-fable-5-on-your-plan

**P15 の検証上の注意**：S65 / S67 / S68 / S69 / S70 / S80 は P15 を出典とする。**P15 は 2026-07-07 公開のまま Opus 5 に更新されていない**（本文は Opus 4.8 期の記述）。台帳はこれを承知の上で、model=how capable / effort=how thorough の枠組みと specialist・expert・generalist の比喩、default-first 原則を「モデル世代に依存しない一般論」として維持している。**個別モデルの推奨開始点は P13 を正とする**。P15 由来の逐語が取得できない場合は「確認不能」と明示すること（憶測で「一致」と判定しない）。

### 実施する検証（5 観点）

1. **`[Official]` 記述の事実性。** `01` の各 source_id（S1〜S106。欠番：S4, S5, S52, S53。Retired：S1, S7, S49）の主張が、記載された出典ページ
   （P1〜P21。P10 は欠番）の内容と一致するかを確認する。古い・誤り・過大/過小表現があれば指摘する。
   特に価格・コンテキスト長・最大出力・effort 既定値・thinking 仕様・データ保持要件・
   refusal の対象領域は、公式の逐語表現と厳密に照合する。

2. **source_id の裏付けの妥当性。** 主張と出典の対応が正しいか。裏付けのない主張が `[Official]`
   として書かれていないか。逆に、公式にあるのに台帳へ未反映の重要事実がないか。

3. **ファイル間の矛盾。** `02` の判断表・分岐フローと、`03/04/05` のモデル別ガイドの記述が
   食い違っていないか。同じ source_id が別ファイルで別の意味に使われていないか。

4. **判断表（`02`）の妥当性。** タスク分類・モデル選定・effort 指定に、公式ポジショニングと
   矛盾する箇所や、明らかな抜けがないか。

5. **`[Heuristic]` の運用仮説。** 公式ポジショニングと矛盾する仮説がないか（仮説であること自体は
   問題ない。公式が否定している事柄を仮説として提示していないかを見る）。

### 併せて必ず確認する整合性チェック（機械的に実施可能）

- **S-id の参照整合性**：`00,02,03,04,05` の各ファイルが参照する `S<数字>` が、すべて `01` に
  定義されているか。定義のない参照（ダングリング）、および定義済みだがどこからも参照されない
  source_id（欠番の意図的宣言を除く）を洗い出す。
- **タグ規律**：`[Official]` の記述に source_id が付いているか。`[Official]` と `[Heuristic]` の
  取り違えがないか。
- **モデル ID・数値の内部整合**：`claude-fable-5` / **`claude-opus-5`** / `claude-sonnet-5`、
  価格（$10/$50, $5/$25, $3/$15）、2576px、~30% トークナイザ増（Sonnet 5）、64k、128k、512 トークン
  （Opus 5 のキャッシュ最小長）、v2.1.219、2026-08-31 導入価格などの数値がファイル間で食い違っていないか。
- **旧モデル名の残存**：`Opus 4.8` / `claude-opus-4-8` / `opus48` が残っている箇所が、
  すべて意図的なもの（フォールバック先・ライフサイクル・移行元・Retired 注記・CHANGELOG）か。
  選定対象や第一/第二候補として 4.8 が残っていれば誤り。

### 特に注意して見るべき既知の落とし穴（先入観で流さない）

- **Opus 4.8 と Opus 5 の混同（最重要）**。**方向が逆転している挙動がある**：4.8 は
  「サブエージェントは少なめに起動」「進捗更新は既定で高品質だから強制スキャフォールドを外す」だが、
  Opus 5 は「委譲が積極的すぎるので条件と上限を明示」「ナレーションが多いので頻度と形を指定」。
  また **Opus 5 は自己検証するので検証指示を削除する**のが公式推奨で、4.8 のガイドにあった
  「報告前に検証させる」を Opus 5 に転用していないか（P16/P17 で確認）。デザイン既定
  （クリーム/セリフ/テラコッタ）は 4.8 の記述であり、Opus 5 の一次ページに同種の記述はない。
- **Opus 4.7 / 4.8 / 5 の三者混同**。effort 既定（4.7 のみ xhigh）、max のゲート表現
  （4.7/4.8 は「evals で headroom を示すときのみ」／Opus 5 は「無制限のトークン支出に見合うとき」）を
  取り違えていないか。P13 のモデル別セクションで区別して確認する。
- **thinking の既定**。Opus 4.8 は明示指定まで off、**Opus 5 は既定 on**、Sonnet 5 も既定 on、
  Fable 5 は常時 on（disable 不可）。**Opus 5 では `thinking:{"type":"disabled"}` と effort
  xhigh/max の併用が 400 エラー**（4.8 では独立だった）。P16/P12/P13 で確認する。
- **effort の既定値**。「Claude API の既定」と「Claude Code の既定」を区別する。どのモデルで
  high か xhigh か、xhigh 明示指定の公式推奨がどのモデルにかかるかを P2/P9/P11/P13/P17 で照合する。
- **effort の持ち越し（Claude Code）**。default hold が明記されているのは Fable 5 / Opus 4.8 /
  Opus 4.7 で、**Opus 5 は hold なし（前回値を持ち越す）**。Sonnet 5 は公式文に列挙されていないので
  台帳も断定していない。P11 の逐語で確認し、Sonnet 5 について断定的な記述があれば指摘する。
- **Covered Model / データ保持**。Covered Model（30 日保持必須・ZDR 不可）に指定されているのは
  **Fable 5 と Mythos 5 のみ**。P12 の "Both models require 30-day data retention..." の "Both" が
  何と何を指すかを本文の文脈で確認する（Opus 5 と読み違えると誤判定になる）。**Opus 4.8 は
  "remains available under ZDR"**、Sonnet 5 も ZDR 可。**Opus 5 は Covered Model 指定なし**だが
  台帳は「全サーフェスで ZDR 可」とは書いていない（ZDR 適格性は機能・サーフェス・契約に依存）。
  P20 の feature eligibility 表も併せて確認する。
- **refusal の対象と誤検知**。安全分類器の対象領域（攻撃的サイバー技術・生物/生命科学・思考抽出）と、
  「良性の作業でも誤検知しうる」旨が **どのモデルについて公式に明記されているか**（Fable 5 のみか、
  Sonnet 5 にも及ぶか）を P3/P5/P7 で区別する。
- **フォールバック**。**サーフェスで挙動が違う**：API はオプトイン（`fallbacks` パラメータ, beta。
  `"default"` でカテゴリ別ルーティング）で、Fable 5 の推奨フォールバック先は Opus 4.8。
  **Claude Code はカテゴリ別に自動**（Fable 5 の bio → Opus 5、Fable 5 の cyber → Opus 4.8、
  Opus 5 の cyber → Opus 4.8、Opus 5 の bio はフォールバックなしで refusal）。P11/P14 で確認する。
  refusal カテゴリの現行列挙値（cyber / bio / frontier_llm / reasoning_extraction / general_harms）も
  P14 で照合する。
- **`opus` エイリアスの解決先**。プロバイダごとに違う（Anthropic API / Claude Platform on AWS /
  Bedrock / Google Cloud → Opus 5、**Microsoft Foundry → Opus 4.6**）。P11 の表で確認する。
- **プラン差**。Fable 5 は全有料プランで「選択可能」だが課金形態が違う（Max / Team Premium /
  legacy seat-based Enterprise Premium 席は内包・週間上限の 50%、Pro / Team Standard 席は
  usage credits）。「Pro では使えない」と書いていれば誤り。P21 で確認する。

### 制約

- 事実判定は **P1〜P21（P10 は欠番）の実ページ内容のみ** を根拠にする。あなたの記憶や訓練データの一般知識で
  「こうだろう」と補完しない。
- Web 取得ができない環境の場合：事実性（観点 1・2）は「確認不能」と明示し、代わりに観点 3・4・5
  と整合性チェック（S-id 参照・タグ規律・内部数値整合）を漏れなく実施する。憶測で「一致」と
  判定しない。
- 各指摘には根拠を添える：公式判定なら「どのページ P__ のどの記述か（できれば引用）」、
  内部整合の指摘なら「どのファイルの何行目・どの source_id か」。
- 勝手にファイルを修正しない。指摘の提示に徹する。

### 出力フォーマット

先に結論、次に詳細。

1. **サマリ**（3〜5 行）：重大な相違の件数、整合性エラーの有無、全体の信頼度の所感。
2. **指摘一覧**（重要度順。各項目に以下を付す）：
   - 分類：`[事実性の相違]` / `[裏付け不足]` / `[ファイル間矛盾]` / `[判断表の抜け・改善余地]` /
     `[Heuristic が公式と矛盾]` / `[S-id 参照エラー]` / `[タグ規律]` / `[内部数値不整合]` /
     `[確認不能]`
   - 該当箇所：ファイル名（＋ source_id / 行番号）
   - 根拠：公式ページ P__ の記述（引用）、または該当ファイルの記述
   - 是正の方向性（任意・一文）
3. **確認済みで問題なしと判断した主要項目**（簡潔に列挙）。何を検証済みかを可視化する。
4. **Web 取得の可否**：どのページを実際に取得できたか、できなかったか。

## Codex に渡す本文（ここまで）
