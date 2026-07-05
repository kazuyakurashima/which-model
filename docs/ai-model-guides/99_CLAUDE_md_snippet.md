# CLAUDE.md 追記スニペット

以下を `CLAUDE.md` に貼る。**全文をコンテキストに載せず、必要時に該当ファイルだけを参照させる**のが狙い。

> **タグ・出典について**：スニペット内の各行は `02_model_selection_matrix.md` の `[Official]` 記述の要約
> （根拠：S1, S6, S7, S9, S10, S16, S29, S65）。貼り付け先の CLAUDE.md ではタグ・source_id を省略する
> （ランタイムのコンテキストにはノイズになるため）。裏付けを確認するときは 01 の台帳を参照。

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
- Sensitive data under ZDR → avoid Fable 5 (ZDR-ineligible); use Opus 4.8.

All `[Official]` claims are backed by docs/ai-model-guides/01_sources_evidence.md.
```

## 配置手順

```bash
# リポジトリ側で
mkdir -p docs/ai-model-guides
# 00〜05 と 99 をコピー
cp 00_index.md 01_sources_evidence.md 02_model_selection_matrix.md \
   03_fable5_prompting.md 04_opus48_prompting.md 05_sonnet5_prompting.md \
   docs/ai-model-guides/
# 上記スニペットを CLAUDE.md に追記
```
