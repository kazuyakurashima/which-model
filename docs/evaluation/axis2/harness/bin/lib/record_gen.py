#!/usr/bin/env python3
"""B プロンプト生成（縮退経路2往復）の費用・時間を記録する。

使い方: record_gen.py <log-dir> <prefix> <prompt-file> <out-json>
        --task .. --rep .. --model .. --effort .. --attempts .. --elapsed ..

**失敗した attempt のコストも足す。** 成功した attempt だけを数えると、
リトライが起きたときに B の実費を過小計上する。`<log-dir>/<prefix>_a*_phase*.log`
を全部拾って合算する。

A 腕にはこの費用が存在しない。**B の総コストにはここを必ず足す**（DESIGN.md §9）。
"""
import argparse
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parse_stream  # noqa: E402


def leg(path: pathlib.Path):
    if not path.exists():
        return {"log": path.name, "status": "missing",
                "cost_usd": None, "duration_ms": None}
    d = parse_stream.parse(path.read_text(encoding="utf-8", errors="replace"))
    return {"log": path.name, "status": d["status"], "cost_usd": d["cost_usd"],
            "duration_ms": d["duration_ms"], "num_turns": d["num_turns"],
            "tool_calls": d["tool_calls"], "session_id": d["session_id"]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir")
    ap.add_argument("prefix")
    ap.add_argument("prompt")
    ap.add_argument("out")
    ap.add_argument("--task", required=True)
    ap.add_argument("--rep", type=int, required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--effort", required=True)
    ap.add_argument("--attempts", type=int, required=True)
    ap.add_argument("--elapsed", type=int, required=True)
    a = ap.parse_args()

    logdir = pathlib.Path(a.logdir)
    legs = [leg(p) for p in sorted(logdir.glob(f"{a.prefix}_a*_phase*.log"))]
    costs = [x["cost_usd"] for x in legs if x["cost_usd"] is not None]
    durs = [x["duration_ms"] for x in legs if x["duration_ms"] is not None]
    prompt = pathlib.Path(a.prompt).read_text(encoding="utf-8")
    payload = {
        "task_id": a.task,
        "rep": a.rep,
        "gen_model": a.model,
        "target_effort": a.effort,
        "attempts": a.attempts,
        "n_legs_counted": len(legs),
        "legs": legs,
        # 失敗した attempt も含む合計（DESIGN.md §9）
        "gen_cost_usd": sum(costs) if costs else None,
        "gen_duration_ms": sum(durs) if durs else None,
        "gen_wall_s": a.elapsed,
        "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
        "prompt_chars": len(prompt),
    }
    pathlib.Path(a.out).write_text(json.dumps(payload, ensure_ascii=False, indent=2),
                                   encoding="utf-8")
    print(f"gen recorded: {a.task} r{a.rep} attempts={a.attempts} "
          f"legs={len(legs)} cost={payload['gen_cost_usd']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
