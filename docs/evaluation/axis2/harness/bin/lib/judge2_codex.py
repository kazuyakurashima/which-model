#!/usr/bin/env python3
"""第2 judge（Codex）の実行ログを解析し、腕へ写像して保存する（DESIGN.md §3）。

使い方: judge2_codex.py <jsonl-log> <last-message-file> <task_id> <rep> <order> <out-json>
        [--rc <exit-code>]

写像は Claude 側と**同じコードを共有する**（parse_judgement.to_arms）。
Codex 用に別の写像を書くと、系統ごとに規則がずれて比較にならない。

次のいずれかに当たる実行は**採用しない**（非ゼロ終了して呼び出し側にリトライさせる）。
判定 JSON が取り出せたことだけを成功の根拠にしない。

- `codex exec` の終了コードが 0 でない
- 正常完了イベントが1つも無い（途中で切れた実行）
- エラーイベントがある
- ツール未使用（`context_required=true` のとき）
"""
import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402
import parse_judgement  # noqa: E402

# Codex の JSONL に現れるイベントのうち、「道具を使った」と数えるもの。
# 実形は bin/probe-codex.sh で確認する（版で変わりうるため広めに取る）。
TOOL_HINTS = ("command", "exec", "shell", "tool", "patch", "apply", "mcp")


def count_tools(events):
    """ツール使用イベント数を数える。開始と完了の対を二重に数えない。"""
    n = 0
    for ev in events:
        t = (ev.get("type") or "")
        # msg 形式（{"type":"item.completed","item":{"item_type":"command_execution"}}）にも対応
        item = ev.get("item") or {}
        it = (item.get("item_type") or item.get("type") or "")
        blob = f"{t}|{it}".lower()
        if not any(h in blob for h in TOOL_HINTS):
            continue
        # 完了イベントだけを数える（begin/started は数えない）
        if any(k in blob for k in ("completed", "end", "output", "result", "done")):
            n += 1
        elif "begin" not in blob and "start" not in blob and "delta" not in blob:
            n += 1
    return n


# 正常完了を示すイベント。**厳密な意味解析はしない**（版で名前が変わりうるため、
# 「終わった」と読める語を含むかだけを見る）。実形は bin/probe-models.sh が記録する。
DONE_HINTS = ("turn.completed", "turn_completed", "thread.finished", "task_complete",
              "session.completed", "response.completed", "turn.done")
ERROR_HINTS = ("error", "failed", "aborted", "interrupted")


def completion(events):
    """(正常完了したか, 説明) を返す。判定と probe で同じ基準を使う。"""
    if not events:
        return False, "イベントが1つも無い"
    types = []
    for ev in events:
        item = ev.get("item") or {}
        types.append(f"{ev.get('type') or ''}|{item.get('item_type') or item.get('type') or ''}"
                     .lower())
    errs = [t for t in types if any(h in t for h in ERROR_HINTS)]
    if errs:
        return False, f"エラーイベントがある: {sorted(set(errs))[:3]}"
    done = [t for t in types if any(h in t for h in DONE_HINTS)]
    if not done:
        return False, ("正常完了イベントが無い（実形が想定と違う可能性。"
                       f"観測した type: {sorted(set(types))[:8]}）")
    return True, f"完了イベント: {sorted(set(done))[:3]}"


def usage_of(events):
    """トークン使用量を拾う（USD は Codex では取れない想定。取れたら入れる）。"""
    usage, cost = None, None
    for ev in reversed(events):
        for key in ("usage", "token_usage", "total_token_usage"):
            u = ev.get(key) or (ev.get("info") or {}).get(key)
            if isinstance(u, dict) and usage is None:
                usage = u
        for key in ("total_cost_usd", "cost_usd"):
            if isinstance(ev.get(key), (int, float)) and cost is None:
                cost = ev[key]
    return usage, cost


def read_events(path):
    events = []
    for line in pathlib.Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def main() -> int:
    ap = argparse.ArgumentParser()
    for name in ("log", "last", "task_id", "rep", "order", "out"):
        ap.add_argument(name)
    ap.add_argument("--rc", default=None, help="codex exec の終了コード")
    a = ap.parse_args()
    log, last, task_id, rep, order, out = (a.log, a.last, a.task_id, a.rep, a.order, a.out)

    # **終了コードを先に見る。** 判定 JSON が取れても、実行が失敗していれば採用しない。
    if a.rc is not None and str(a.rc) != "0":
        print(f"ERROR: codex exec の終了コードが {a.rc}", file=sys.stderr)
        return 1

    events = read_events(log)
    ok_done, why = completion(events)
    if not ok_done:
        print(f"ERROR: Codex の実行が正常完了していない — {why}", file=sys.stderr)
        return 1

    body = ""
    lp = pathlib.Path(last)
    if lp.is_file():
        body = lp.read_text(encoding="utf-8", errors="replace")
    d = parse_judgement.extract_json(body)
    if d is None:
        # last-message が空なら JSONL 側の最終メッセージからも探す
        joined = "\n".join(json.dumps(e, ensure_ascii=False) for e in events[-40:])
        d = parse_judgement.extract_json(joined)
    if d is None:
        print("ERROR: Codex の判定 JSON を取り出せなかった", file=sys.stderr)
        return 1

    task = common.task_by_id()[task_id]
    tools = count_tools(events)
    # **実装を読まずに文章だけ比べた判定は採用しない**（Claude 側と同じ基準）。
    if task["context_required"] and tools == 0:
        print("ERROR: context_required=true なのに Codex がツールを使っていない",
              file=sys.stderr)
        return 1

    winner, critical = parse_judgement.to_arms(d["verdict"], order)
    usage, cost = usage_of(events)
    cfg = common.config()
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
        "judge_family": "codex",
        "judge_model": cfg.get("judge2_model"),
        "judge_effort": cfg.get("judge2_effort"),
        "judge_cost_usd": cost,
        "judge_usage": usage,
        "judge_tool_calls": tools,
        "n_events": len(events),
        "completion": why,
    }
    pathlib.Path(out).write_text(json.dumps(payload, ensure_ascii=False, indent=2),
                                 encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
