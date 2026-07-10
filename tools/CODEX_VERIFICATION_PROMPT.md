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
- `01_sources_evidence.md` … **根拠台帳**。全 `[Official]` 記述の source_id（S1〜S70。欠番：S4, S5, S52, S53）と公式出典（P1〜P15。欠番：P10）の対応表。ここが正の起点。
- `02_model_selection_matrix.md` … タスク×モデル×effort の判断表
- `03_fable5_prompting.md` / `04_opus48_prompting.md` / `05_sonnet5_prompting.md` … モデル別プロンプティングガイド

（補助として、リポジトリ README.md 末尾の CLAUDE.md 追記スニペットも同じタグ規律に従う。）

この知識ベースは 2 層構造で、各記述に必ずタグが付く：
- `[Official]` … Anthropic 公式で確認できる事実。必ず `01` の source_id に紐づく。
- `[Heuristic]` … プロジェクト固有の運用仮説。公式裏付けなし。Confidence 付き。

対象モデルは Claude Fable 5 / Opus 4.8 / Sonnet 5 の 3 つ（いずれも 2026 年のモデル。
あなたの学習データより新しい可能性が高いが、実在する）。

### 公式一次情報（`01` の P1〜P15。P10 は欠番・未参照。ここだけを事実の根拠にする）

- P1  Models overview — https://platform.claude.com/docs/en/about-claude/models/overview
- P2  Choosing the right model — https://platform.claude.com/docs/en/about-claude/models/choosing-a-model
- P3  Introducing Claude Fable 5 and Claude Mythos 5 — https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5
- P4  What's new in Claude Opus 4.8 — https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8
- P5  What's new in Claude Sonnet 5 — https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5
- P6  Prompting best practices — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- P7  Prompting Claude Fable 5 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- P8  Prompting Claude Opus 4.8 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8
- P9  Prompting Claude Sonnet 5 — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5
- P10 〈欠番・未参照。どの source_id からも参照されない（`01` の「欠番について」参照）〉
- P11 Model configuration (Claude Code) — https://code.claude.com/docs/en/model-config
- P12 Migration guide — https://platform.claude.com/docs/en/about-claude/models/migration-guide
- P13 Effort — https://platform.claude.com/docs/en/build-with-claude/effort
- P14 Refusals and fallback — https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback
- P15 Choosing a Claude model and effort level in Claude Code（公式ブログ、2026-07-07 公開） — https://claude.com/blog/claude-model-and-effort-level-in-claude-code

**P15 の検証上の注意**：S65 / S67 / S68 / S69 / S70 は P15 を出典とする。`01` の「引用の逐語検証の情報源」注記のとおり、これらの英文キーフレーズは公式ページの直接取得ではなく**メンテナが照合した P15 本文**に基づく。可能なら P15 の恒久 URL を取得して逐語を再照合し、取得不能なら「確認不能」と明示すること（憶測で「一致」と判定しない）。

### 実施する検証（5 観点）

1. **`[Official]` 記述の事実性。** `01` の各 source_id（S1〜S70。欠番：S4, S5, S52, S53）の主張が、記載された出典ページ
   （P1〜P15。P10 は欠番）の内容と一致するかを確認する。古い・誤り・過大/過小表現があれば指摘する。
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
- **モデル ID・数値の内部整合**：`claude-fable-5` / `claude-opus-4-8` / `claude-sonnet-5`、
  価格（$10/$50, $5/$25, $3/$15）、2576px、~30% トークナイザ増、64k、128k、2026-08-31 導入価格
  などの数値がファイル間で食い違っていないか。

### 特に注意して見るべき既知の落とし穴（先入観で流さない）

- **Opus 4.7 と Opus 4.8 の混同**。プロンプティング挙動には 4.7 由来のものと 4.8 固有のものが
  ある。文体（4.8 は「直接的・断定的」が公式表現か、「温かい」か）、応答長、effort 既定を、
  必ず Opus 4.8 の一次ページ（P4/P8）で確認する。4.7 の記述を 4.8 に転用していないか。
- **effort の既定値**。「Claude API の既定」と「Claude Code の既定」を区別する。どのモデルで
  high か xhigh か、xhigh 明示指定の公式推奨がどのモデルにかかるかを P2/P8/P9/P11/P13 で照合する。
- **Covered Model / データ保持**。Fable 5 の 30 日保持・ZDR 不可・Covered Model 指定の有無を
  P3/P12 の逐語で確認する。
- **refusal の対象と誤検知**。安全分類器の対象領域（攻撃的サイバー技術・生物/生命科学・思考抽出）と、
  「良性の作業でも誤検知しうる」旨が **どのモデルについて公式に明記されているか**（Fable 5 のみか、
  Sonnet 5 にも及ぶか）を P3/P5/P7 で区別する。
- **フォールバック**。API ではオプトイン（`fallbacks` パラメータ, beta）か、Claude Code では
  自動か、を P11/P12/P14 で確認する。

### 制約

- 事実判定は **P1〜P15（P10 は欠番）の実ページ内容のみ** を根拠にする。あなたの記憶や訓練データの一般知識で
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
