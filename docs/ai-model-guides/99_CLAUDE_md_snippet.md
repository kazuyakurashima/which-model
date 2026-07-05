# CLAUDE.md 追記スニペット

以下を `CLAUDE.md` に貼る。**全文をコンテキストに載せず、必要時に該当ファイルだけを参照させる**のが狙い。

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
- Unsure / complex agentic coding → Opus 4.8 (default). Try effort=high, xhigh for hard work.
- Fast, high-frequency, or simple → Sonnet 5. Do not use Fable 5 for these.
- Long, ambiguous, hours-to-weeks, end-to-end → Fable 5. Set up timeouts, progress, and refusal fallback first.
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
