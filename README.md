# model-router

Claude Code で、指示内容に応じて最適な Claude モデル（Fable 5 / Opus 4.8 / Sonnet 5）と
effort レベルを提示し、選んだモデル向けに最適化したプロンプトを表示する skill です
（表示でいったん止まり、ユーザーが確認して `y` を送ると実行。skill 自身は勝手に実行しません）。

> このファイルは人間向けの説明書です。Claude Code は読み込みません（トークンを消費しません）。
> Claude への動作指示は `SKILL.md` に、判断材料は `docs/ai-model-guides/` にあります。

## これは何をするか

VS Code などの Claude Code で開発していると、指示のたびに「どのモデルが最適か」「プロンプトを
そのモデル向けにどう書くか」で迷い、選定を誤ると手戻りが起きます。この skill は、その2つを
半自動化します。

1. あなたが `/model-router <指示>` と入力する
2. skill が指示内容（設計・実装・リファクタ等）と複雑さを判定し、推奨モデルと effort を理由つきで提示して停止する
3. あなたは必要なら `/model` でモデルを切り替える（不要ならそのまま）
4. 実行合図を送ると、確定したモデル向けに最適化したプロンプトを表示して**いったん停止する**
   - 推奨モデルのまま → `y`
   - 代替モデルに切り替えた → `y opus` / `y fable` / `y sonnet` とモデル名を添える
5. 中身を確認し、よければ**もう一度 `y`** を送ると実行される（コピペ不要）。直したいときは
   表示されたプロンプトを編集して送る。この「表示 → 確認 → `y` で実行」の一拍が暴走を防ぐ

## 仕組み（料理人とレシピ本）

この skill は2つの部品でできています。

- **SKILL.md（料理人）**：動作の段取りだけを書いた、Claude への指示書。PC 本体に1つ置く。
- **docs/ai-model-guides/（レシピ本）**：判断材料。各プロジェクトに置く。

料理人は判断材料を自分で持たず、開いているプロジェクトのレシピ本を読んで判断します。だから
プロジェクトごとに判断基準を微調整でき、モデル仕様の更新にも追従できます。

レシピ本は6ファイル構成です。

| ファイル | 役割 |
| --- | --- |
| `00_index.md` | 全体の使い方・読み込みルール |
| `01_sources_evidence.md` | 根拠台帳（公式主張を source_id で管理） |
| `02_model_selection_matrix.md` | タスク別のモデル/effort 判断表（料理人が毎回読む中核） |
| `03_fable5_prompting.md` | Fable 5 向けプロンプト最適化ガイド |
| `04_opus48_prompting.md` | Opus 4.8 向けプロンプト最適化ガイド |
| `05_sonnet5_prompting.md` | Sonnet 5 向けプロンプト最適化ガイド |

このほかリポジトリ直下に、配布物ではない開発用ファイルがあります：
`tools/CODEX_VERIFICATION_PROMPT.md`（知識ベースの独立監査用プロンプト。各プロジェクトへはコピーしない）。

各ガイドの記述には2種類のタグが付いています。`[Official]` は Anthropic 公式ドキュメントで
裏付けられた事実（`01` の source_id に対応）、`[Heuristic]` は配布元の運用仮説（公式の裏付けなし、
Confidence 付き）です。使う人は `[Heuristic]` を自分の使い方に合わせて書き換えてください。

## セットアップ

料理人は PC 本体に、レシピ本は各プロジェクトに置きます。

### 料理人（SKILL.md）

**このリポジトリの `SKILL.md` が正本**です。`./install.sh` を実行すると
`~/.claude/skills/model-router/SKILL.md` へコピーされます（既存と差分があれば表示して確認）。
手動で置く場合の場所：

- **Mac**：`~/.claude/skills/model-router/SKILL.md`
- **Windows**：`%USERPROFILE%\.claude\skills\model-router\SKILL.md`

SKILL.md を編集するときは必ずリポジトリ側を直し、`./install.sh` で反映してください。
（`.prettierignore` で SKILL.md を除外しています。Markdown 自動整形が手順のネスト構造を
壊すためです。）

### レシピ本（docs/ai-model-guides/）

使いたいプロジェクトのルートに `docs/ai-model-guides/` を作り、6ファイルを置きます。

```
<your-project>/
  docs/
    ai-model-guides/
      00_index.md
      01_sources_evidence.md
      02_model_selection_matrix.md
      03_fable5_prompting.md
      04_opus48_prompting.md
      05_sonnet5_prompting.md
```

## 使い方

迷ったとき・重要な設計や大規模作業のときだけ、明示的に呼びます。

```
/model-router 複数ユーザー対応のタスク管理アプリを設計して
```

推奨が提示され停止したら、必要に応じて `/model claude-fable-5` などで切り替え、実行合図を
送ります（推奨のまま `y`、代替に変えたら `y opus` / `y fable` / `y sonnet`）。すると最適化された
プロンプトが表示されて停止するので、中身を確認して**もう一度 `y`** を送れば実行されます。普段の
軽い作業では呼ばず、設定済みのモデルでそのまま指示すれば十分です。

CLAUDE.md には登録しないことを推奨します。登録すると毎回自動で判定が走り、日々の開発テンポを
損なうためです（それでも常時参照させたい場合のスニペットは付録を参照）。

## 呼び方のコツ（重要）

- **必ず行頭に `/model-router` を付けて呼ぶ。** うしろは、やりたいことを普段どおり書くだけでよい
  （自分でプロンプトを整える必要はない。整えるのが skill の仕事）。
  - 例：`/model-router 認証まわりを大規模リファクタして`
  - 「リファクタして」のような実行命令のままでよい。skill が起動していれば、実行はせず
    「推奨モデル＋最適化プロンプト」を返して止まる（稼働中は読み取り専用なので、そもそも実行できない）。
- **提案が出ず、いきなり作業（ファイル編集など）が始まったら、skill が起動していないサイン。**
  一度止めて、`/model-router …` を行頭単独で打ち直す。
- スラッシュを使わず自然文で呼ぶときは、「どのモデルがいい？」「〜用のプロンプトにして」のように
  “実行” ではなく “提案・最適化” を求める言い回しにすると起動しやすい。

## 設計上の割り切り（既知の制約）

現状の Claude Code の仕様上、以下は実現できません。理解した上で使ってください。

- **モデルの自動切替はできない**。skill は推奨を提示するのみで、`/model` での切替はユーザーが
  手動で行います（2026-07 時点の Claude Code の仕様。公式ドキュメントの明文根拠は未確認）。
- **現在のモデルを skill 側から知る手段がない**ため、モデル不一致の自動警告はできません。
- **提示後にポップアップ（AskUserQuestion）を出さない設計**にしています。ポップアップが出ると
  入力欄が塞がれ、モデル切替ができなくなるためです。代わりに一度停止し、`y` を実行の合図とします。

## カスタマイズ（配布を受けた人向け）

- `docs/ai-model-guides/02_model_selection_matrix.md` の判断表と、各ガイド（03〜05）を、
  自分のプロジェクトの事情（扱うデータ、作るアプリの種類、コスト方針）に合わせて調整してください。
- `[Heuristic]` タグの記述は配布元の経験則です。自分の使い方に合わせて書き換えてください。
- `[Official]` タグの記述は公式裏付けがあります。モデル世代が変わるまで基本そのままで問題ありません。
- 各ファイル冒頭の `Last verified` 日付が古くなったら（目安：1〜2ヶ月）、公式ドキュメントで
  再確認してください。モデルの仕様・価格は頻繁に変わります。

## 付録：CLAUDE.md 追記スニペット（任意・本運用では非推奨）

上記の通り本運用では CLAUDE.md への登録は推奨しませんが、skill を使わず常時参照させたい
場合は以下を CLAUDE.md に貼ってください。各行は `02_model_selection_matrix.md` の
記述の要約です（根拠：S1, S6, S7, S9, S10, S16, S25, S29, S65。うち「速い対話・高頻度は Sonnet 5 /
Fable 5 不使用」と「ZDR 前提の代替モデル選択」は公式事実から導く運用判断（`[Heuristic]`）。
タグ・source_id はランタイムのノイズになるため省略。裏付けは `01_sources_evidence.md` を参照）。

```md
## Model routing & prompt optimization

When choosing which Claude model to use, or optimizing a prompt for a specific
model, consult these guides. Read only the file relevant to the current task —
do not load all of them.

- Deciding which model for a task → docs/ai-model-guides/02_model_selection_matrix.md
- Prompting Fable 5 (claude-fable-5) → docs/ai-model-guides/03_fable5_prompting.md
- Prompting Opus 4.8 (claude-opus-4-8) → docs/ai-model-guides/04_opus48_prompting.md
- Prompting Sonnet 5 (claude-sonnet-5) → docs/ai-model-guides/05_sonnet5_prompting.md

Quick defaults:
- Unsure / complex agentic coding → Opus 4.8 (default). Effort defaults to high;
  set xhigh explicitly for coding and high-autonomy work (official guidance).
- Fast, high-frequency, or simple → Sonnet 5 (effort=low for simple lookups). Do not use Fable 5 for these.
- Long, ambiguous, hours-to-weeks, end-to-end → Fable 5 (start at effort=high). Set up timeouts,
  progress, and refusal fallback first (Claude Code falls back automatically).
- Adjust effort before switching models.
- Sensitive data under ZDR → avoid Fable 5 (ZDR-ineligible); use Opus 4.8 or Sonnet 5.

All `[Official]` claims are backed by docs/ai-model-guides/01_sources_evidence.md.
```

## ライセンス

（公開時に記載）
