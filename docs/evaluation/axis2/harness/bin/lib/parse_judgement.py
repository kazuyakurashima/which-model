#!/usr/bin/env python3
"""judge の実行ログから判定 JSON を取り出し、腕（A/B）へ写像して保存する。

使い方: parse_judgement.py <raw-log> <task_id> <rep> <order> <out-json>

写像は STOP-RULES.md §1 の表に従う（結果を見てから変えないこと）。
  左=A/右=B のとき  left_better → A ／ right_better → B
  左=B/右=A のとき  left_better → B ／ right_better → A
  tie → 引き分け
  critical_error_<側> → 相手側の勝ち。加えてその側に critical error を1件記録

判定不能・パース失敗・**context_required=true でツール未使用**は非ゼロ終了
（呼び出し側がリトライする）。
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parse_stream  # noqa: E402

VERDICTS = {"left_better", "right_better", "tie",
            "critical_error_left", "critical_error_right"}


def extract_json(text):
    """本文から最後の JSON オブジェクトを取り出す（前後の説明文に耐える）。"""
    text = text.strip()
    fences = re.findall(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.S)
    cands = list(fences)
    # 素の {...} も拾う（ネスト無しの単純な形を想定）
    depth = 0
    start = None
    for i, ch in enumerate(text):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            if depth > 0:
                depth -= 1
                if depth == 0 and start is not None:
                    cands.append(text[start:i + 1])
    for c in reversed(cands):
        try:
            d = json.loads(c)
        except json.JSONDecodeError:
            continue
        if isinstance(d, dict) and d.get("verdict") in VERDICTS:
            return d
    return None


def to_arms(verdict, order):
    """verdict を勝者の腕と critical error の腕へ写像する。"""
    left_arm, right_arm = order[0], order[1]
    if verdict == "left_better":
        return left_arm, None
    if verdict == "right_better":
        return right_arm, None
    if verdict == "tie":
        return "tie", None
    if verdict == "critical_error_left":
        return right_arm, left_arm
    if verdict == "critical_error_right":
        return left_arm, right_arm
    raise ValueError(verdict)


def main() -> int:
    raw, task_id, rep, order, out = sys.argv[1:6]
    text = pathlib.Path(raw).read_text(encoding="utf-8", errors="replace")
    parsed = parse_stream.parse(text)
    # is_error のエラー応答を判定として採用しない（リトライさせる）
    if parsed["status"] != "ok":
        print(f"ERROR: judge の実行が status={parsed['status']}", file=sys.stderr)
        return 1
    # 与えたはずのツールが拒否された判定も採用しない（材料を見られていない）
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import common  # noqa: E402
    task = common.task_by_id()[task_id]
    granted = set(task["allowed_tools"]) if task["context_required"] else set()
    denied_granted = sorted({t for t in parse_stream.denied_tools(parsed) if t in granted})
    if denied_granted:
        print(f"ERROR: judge に与えたツールが拒否された: {denied_granted}", file=sys.stderr)
        return 1
    # **実装を読まずに文章だけ比べた判定は採用しない**（Codex 側と同じ基準。
    # 片方の系統だけに課すと基準が非対称になり、系統間の一致率が比較にならない）。
    if task["context_required"] and not parsed["tool_calls"]:
        print("ERROR: context_required=true なのに judge がツールを使っていない",
              file=sys.stderr)
        return 1
    body = parsed["result"]
    d = extract_json(body)
    if d is None:
        print("ERROR: judge の JSON を取り出せなかった", file=sys.stderr)
        return 1
    winner, critical = to_arms(d["verdict"], order)
    payload = {
        "task_id": task_id,
        "rep": int(rep),
        "order": order,
        "left_arm": order[0],
        "right_arm": order[1],
        "verdict": d["verdict"],
        "winner_arm": winner,
        "critical_error_arm": critical,
        "reason": d.get("reason", ""),
        "evidence": d.get("evidence", ""),
        "judge_cost_usd": parsed["cost_usd"],
        "judge_duration_ms": parsed["duration_ms"],
        # judge が実際にリポジトリを読んだかの確認用（context_required=true で 0 なら怪しい）
        "judge_tool_calls": parsed["tool_calls"],
    }
    pathlib.Path(out).write_text(json.dumps(payload, ensure_ascii=False, indent=2),
                                 encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
