#!/usr/bin/env python3
"""プローブの結果を probe.json へ記録する（部分ごと・履歴つき）。

使い方:
  probe_record.py <axroot> --part fable --success yes|no --rc N --log F
                          [--actual-model M] [--status S]
  probe_record.py <axroot> --part codex --rc N --log F --last F
  probe_record.py <axroot> --finalize

**部分ごとに success を持つ。** 全体が失敗でも、成功した部分は呼び直さない。
**実際に試行したときは、最新の結果で parts を上書きする**（過去の成功で最新の失敗を隠さない）。
**skip したときはこのスクリプトを呼ばない。** 元の記録・ログ参照・費用・日時をそのまま保ち、
history も増やさない（呼んでいない試行を履歴に残さないため）。
"""
import argparse
import datetime
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parse_stream  # noqa: E402


def load(ax: pathlib.Path):
    p = ax / "probe.json"
    if p.is_file():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    return {"parts": {}, "history": [], "lost_attempts": []}


def save(ax: pathlib.Path, d):
    (ax / "probe.json").write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n",
                                   encoding="utf-8")


def rel(ax: pathlib.Path, p):
    if not p:
        return None
    try:
        return str(pathlib.Path(p).relative_to(ax))
    except ValueError:
        return str(p)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("axroot")
    ap.add_argument("--part", choices=["fable", "codex"])
    ap.add_argument("--success")
    ap.add_argument("--rc")
    ap.add_argument("--log")
    ap.add_argument("--last")
    ap.add_argument("--actual-model", dest="actual_model")
    ap.add_argument("--status")
    ap.add_argument("--finalize", action="store_true")
    a = ap.parse_args()

    ax = pathlib.Path(a.axroot)
    d = load(ax)
    now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")

    if a.part == "fable":
        ok = (a.success == "yes")
        entry = {"success": ok, "at": now, "rc": int(a.rc or 0),
                 "log": rel(ax, a.log), "actual_model": a.actual_model,
                 "status": a.status}
        if a.log and pathlib.Path(a.log).is_file():
            r = parse_stream.parse(pathlib.Path(a.log).read_text(errors="replace"))
            entry["cost_usd"] = r.get("cost_usd")
            u = r.get("usage") or {}
            entry["cache_creation_input_tokens"] = u.get("cache_creation_input_tokens")
            entry["output_tokens"] = u.get("output_tokens")
        # **実際に試行したのだから、最新の結果を現在の判定にする。**
        # 過去の成功を残して最新の失敗を隠すと、壊れた前提のまま先へ進んでしまう。
        d["parts"]["fable"] = entry
        d.setdefault("history", []).append({"part": "fable", **entry})

    elif a.part == "codex":
        sys.path.insert(0, str(ax / "bin" / "lib"))
        import judge2_codex as jc
        events = jc.read_events(a.log) if a.log else []
        done_ok, done_why = jc.completion(events)
        tools = jc.count_tools(events)
        usage, cost = jc.usage_of(events)
        lastp = pathlib.Path(a.last) if a.last else None
        last = (lastp.read_text(encoding="utf-8", errors="replace")
                if lastp and lastp.is_file() else "")
        verdict = jc.parse_judgement.extract_json(last)
        problems = []
        if str(a.rc) != "0":
            problems.append(f"codex exec の終了コードが {a.rc}")
        if not done_ok:
            problems.append(f"正常完了していない — {done_why}")
        if not (lastp and lastp.is_file()):
            problems.append("last-message ファイルが作られなかった")
        elif not (verdict and verdict.get("verdict")):
            problems.append("判定 JSON を取り出せなかった（--output-schema か -o の扱い）")
        if tools == 0:
            problems.append("ツール使用を数えられなかった（judge2_codex.TOOL_HINTS を実形へ）")
        # エラー本文を拾って残す（原因が version 不足なのか権限なのかを見分けるため）
        errs = [str(e.get("message") or (e.get("error") or {}).get("message"))[:400]
                for e in events
                if "error" in (e.get("type") or "") or "fail" in (e.get("type") or "")]
        entry = {"success": not problems, "at": now, "rc": int(a.rc or 0),
                 "log": rel(ax, a.log), "last": rel(ax, a.last),
                 "events": len(events), "completion_ok": done_ok,
                 "completion_detail": done_why, "tool_calls_counted": tools,
                 "event_types": sorted({f"{e.get('type')}|"
                                        f"{(e.get('item') or {}).get('item_type') or ''}"
                                        for e in events}),
                 "usage": usage, "cost_usd": cost, "cost_available": cost is not None,
                 "schema_ok": bool(verdict and verdict.get("verdict")),
                 "problems": problems, "error_messages": errs[:3]}
        # 同上。試行した以上、最新の結果が現在の判定である。
        d["parts"]["codex"] = entry
        d.setdefault("history", []).append({"part": "codex", **entry})

    if a.finalize or a.part:
        parts = d.get("parts", {})
        problems = []
        if not parts.get("fable", {}).get("success"):
            problems.append("Fable 5.1 のプローブが未成功")
        for p in parts.get("codex", {}).get("problems", []) or (
                [] if parts.get("codex", {}).get("success") else ["Codex のプローブが未成功"]):
            problems.append(f"Codex: {p}")
        d["success"] = not problems
        d["problems"] = problems
        d["at"] = now

    save(ax, d)

    if a.finalize:
        print(json.dumps({k: d[k] for k in ("at", "success", "problems")},
                         ensure_ascii=False, indent=2))
        if d["problems"]:
            print("\n**プローブ失敗。本実行へ進まないこと。**", file=sys.stderr)
            for p in d["problems"]:
                print(f"  - {p}", file=sys.stderr)
            for m in d["parts"].get("codex", {}).get("error_messages", []):
                print(f"    Codex のエラー: {m}", file=sys.stderr)
            print("\n自動リトライはしない。成功済みの部分は呼び直さないので、"
                  "直したあと同じコマンドで再実行すること。", file=sys.stderr)
            return 1
        print("\nプローブ: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
