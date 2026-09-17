#!/usr/bin/env python3
"""配管テスト用の偽 `codex`。**モデルを呼ばない＝無料。**

CODEX_BIN にこれを指すと、grade2-codex.sh の全経路を課金なしで通せる。
`codex exec ... --json -o <last> --output-schema <schema> "<prompt>"` を受け取り、
JSONL のイベント列を stdout へ、最終 JSON を -o のファイルへ書く。

判定は fixture タスクの id で決め打ちにし、Claude 側（fake-claude.py）との
**一致・不一致**を作り分ける。
  f01 … Claude と一致（B勝ち）        → 自動確定
  f02 … Claude は unresolved、こちらは B 勝ち → 不一致 → 人間確認へ
  f03 … Claude と一致（A に critical error）  → 確定 critical
  f04 … Claude は B勝ち、こちらは A勝ち      → 不一致 → 人間確認へ
"""
import json
import re
import sys


def argval(argv, *names):
    for name in names:
        if name in argv:
            i = argv.index(name)
            if i + 1 < len(argv):
                return argv[i + 1]
    return None


def emit(events):
    for ev in events:
        print(json.dumps(ev, ensure_ascii=False))


def main() -> int:
    argv = sys.argv[1:]
    if "--version" in argv or "-V" in argv:
        print("fake-codex 0.0.0 (plumbing test)")
        return 0
    if not argv or argv[0] != "exec":
        print("fake-codex: exec 以外は未対応", file=sys.stderr)
        return 2

    last = argval(argv, "-o", "--output-last-message")
    prompt = argv[-1] if argv[-1] and not argv[-1].startswith("-") else ""
    m = re.search(r"\[\[FIXTURE:(\w+)\]\]", prompt or "")
    fid = m.group(1) if m else "f00"
    # 提示順を推測する。**回答本文の印（fake-claude が書く GEN=B）で判定する。**
    # プロンプト側の [[B-PROMPT]] は判定プロンプトには載らない（judge に使用プロンプトは渡さない）。
    left = re.search(r"<左の回答>(.*?)</左の回答>", prompt or "", re.S)
    left_body = left.group(1) if left else ""
    left_is_b = "GEN=B" in left_body

    # ツールを使ったことにするか（context_required の fixture だけ）
    use_tools = fid in ("f01", "f03", "f04")

    if fid == "f01":                      # Claude と一致：B 勝ち
        verdict = "left_better" if left_is_b else "right_better"
    elif fid == "f02":                    # Claude は unresolved：こちらは B 勝ち
        verdict = "left_better" if left_is_b else "right_better"
    elif fid == "f03":                    # A に critical（Claude と一致）
        verdict = "critical_error_right" if left_is_b else "critical_error_left"
    elif fid == "f04":                    # Claude は B、こちらは A（不一致）
        verdict = "right_better" if left_is_b else "left_better"
    else:
        verdict = "tie"

    payload = {"verdict": verdict, "reason": "fixture", "evidence": "fixture"}

    events = [{"type": "session.created", "session_id": "fake-codex"}]
    if use_tools:
        events += [
            {"type": "item.started", "item": {"item_type": "command_execution"}},
            {"type": "item.completed", "item": {"item_type": "command_execution",
                                                "command": "rg -n foo"}},
            {"type": "item.completed", "item": {"item_type": "command_execution",
                                                "command": "cat bar"}},
        ]
    events += [
        {"type": "item.completed", "item": {"item_type": "agent_message",
                                            "text": json.dumps(payload, ensure_ascii=False)}},
        {"type": "turn.completed",
         "usage": {"input_tokens": 1234, "output_tokens": 56}},
    ]
    emit(events)
    if last:
        with open(last, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
