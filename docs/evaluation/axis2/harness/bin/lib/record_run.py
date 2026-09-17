#!/usr/bin/env python3
"""回答実行の生ログを outputs/ 用 JSON にまとめる（旧 wrap_run.py の移植・拡張）。

使い方: record_run.py <raw-log> <out-json> --task .. --arm .. --rep .. --model ..
        --effort .. --prompt-file .. --workdir .. --tools .. --claude-version ..
        --elapsed .. --rc ..

B 腕は gen/<task>_r<rep>.json のプロンプト生成費用を読み、合計へ足す（DESIGN.md §9）。
実行失敗・パース失敗でも status を付けて必ず書き出す（分析側が状態を集計できるように）。
"""
import argparse
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402
import parse_stream  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    for k in ("task", "arm", "model", "effort", "prompt_file", "workdir",
              "tools", "claude_version"):
        ap.add_argument(f"--{k.replace('_', '-')}", dest=k, required=True)
    # 期待する実モデル ID（tasks.json の model_id）。stream-json の init と突き合わせる。
    ap.add_argument("--expect-model", dest="expect_model", default=None)
    ap.add_argument("--rep", type=int, required=True)
    ap.add_argument("--elapsed", type=int, required=True)
    ap.add_argument("--rc", type=int, required=True)
    a = ap.parse_args()

    prompt = pathlib.Path(a.prompt_file).read_text(encoding="utf-8")
    raw = pathlib.Path(a.raw).read_text(encoding="utf-8", errors="replace")
    d = parse_stream.parse(raw)

    gen_cost = gen_ms = None
    if a.arm == "B":
        g = common.AX / "gen" / f"{a.task}_r{a.rep}.json"
        if g.exists():
            gd = json.loads(g.read_text(encoding="utf-8"))
            gen_cost, gen_ms = gd.get("gen_cost_usd"), gd.get("gen_duration_ms")

    # **与えたはずのツールが拒否されたら失敗扱い。** 装置側の不具合であって、
    # その run は比較に使えない。与えていないツール（Bash 等）への拒否は想定内なので数えるだけ。
    granted = set(a.tools.split())
    denied = parse_stream.denied_tools(d)
    denied_granted = sorted({t for t in denied if t in granted})

    status = ("ok" if a.rc == 0 and d["status"] == "ok" else
              (d["status"] if d["status"] != "ok" else "run_failed"))
    if status == "ok" and denied_granted:
        status = "permission_denied_on_granted_tool"
    # **指定と違うモデルで走った run は ok にしない。**
    # エイリアスの解決先が経路で変わるため（S142）、実測と突き合わせないと
    # 「Fable 5.1 で測った」つもりが 5 だったという取り違えを検出できない。
    actual = d.get("actual_model")
    if status == "ok" and a.expect_model:
        if actual is None:
            status = "actual_model_unknown"
        elif actual != a.expect_model:
            status = "model_mismatch"

    ans_cost = d["cost_usd"]
    ans_ms = d["duration_ms"]
    payload = {
        "task_id": a.task,
        "arm": a.arm,
        "rep": a.rep,
        "model": a.model,
        "effort": a.effort,
        "workdir": a.workdir,
        "allowed_tools": a.tools,
        "expect_model": a.expect_model,
        "actual_model": actual,
        "claude_version": a.claude_version,
        "exit_code": a.rc,
        "elapsed_s": a.elapsed,
        "log_format": d["format"],
        "status": status,
        "is_error": d["is_error"],
        "denied_tools": denied,
        "denied_granted_tools": denied_granted,
        "result": d["result"],
        "output_chars": len(d["result"]),
        "tool_calls": d["tool_calls"],
        "tool_names": d["tool_names"],
        "num_turns": d["num_turns"],
        "permission_denials": d["permission_denials"],
        "usage": d["usage"],
        "answer_cost_usd": ans_cost,
        "answer_duration_ms": ans_ms,
        "gen_cost_usd": gen_cost,
        "gen_duration_ms": gen_ms,
        "total_cost_usd": _add(ans_cost, gen_cost),
        "total_duration_ms": _add(ans_ms, gen_ms),
        "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
        "prompt_chars": len(prompt),
    }
    if payload["status"] != "ok":
        payload["raw_head"] = raw[:2000]
        print(f"WARN: status={payload['status']}: {a.task}_{a.arm}_r{a.rep}"
              + (f" 拒否されたツール: {denied_granted}" if denied_granted else "")
              + (f" 期待 {a.expect_model} / 実測 {actual}"
                 if payload["status"] in ("model_mismatch", "actual_model_unknown") else ""),
              file=sys.stderr)
    pathlib.Path(a.out).write_text(json.dumps(payload, ensure_ascii=False, indent=2),
                                   encoding="utf-8")
    return 0 if payload["status"] == "ok" else 1


def _add(x, y):
    vals = [v for v in (x, y) if v is not None]
    return sum(vals) if vals else None


if __name__ == "__main__":
    sys.exit(main())
