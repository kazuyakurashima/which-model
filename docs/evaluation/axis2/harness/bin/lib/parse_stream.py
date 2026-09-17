#!/usr/bin/env python3
"""claude の実行ログ（stream-json / json）から実測値を取り出す。

使い方: parse_stream.py <raw-log> [--out <json>]

stream-json は1行1イベントの JSONL。
- assistant イベントの content 内 `tool_use` ブロックを数える → tool_calls
- 最後の `type == "result"` イベントから result / cost / duration / usage を取る

`--output-format json` の単一オブジェクトも受け付ける（その場合 tool_calls は
数えられないので None。num_turns を代理指標として別に持つ）。

本文の grep でツール使用を判定しないこと：モデルが `[1 tool called]` 等の文字列を
自分で書くことがある（旧版 Pilot 0 の実測）。
"""
import argparse
import json
import pathlib
import sys


def _blocks(msg):
    if not isinstance(msg, dict):
        return []
    c = msg.get("content")
    return c if isinstance(c, list) else []


def parse(text):
    out = {
        "status": "parse_failed",
        "result": "",
        "tool_calls": None,
        "tool_names": [],
        "num_turns": None,
        "cost_usd": None,
        "duration_ms": None,
        "usage": None,
        "permission_denials": None,
        "is_error": None,
        "session_id": None,
        "format": None,
        # stream-json の system/init に出る**実際に使われたモデル ID**。
        # エイリアス（fable 等）は経路によって別世代へ解決する（S142）ので、
        # 指定した ID と一致したかをここで確認する。json 形式では取れない（None）。
        "actual_model": None,
    }
    stripped = text.strip()
    if not stripped:
        return out

    # まず単一 JSON オブジェクト（--output-format json）を試す
    try:
        obj = json.loads(stripped)
        if isinstance(obj, dict) and obj.get("type") == "result":
            out["format"] = "json"
            _fill_result(out, obj)
            out["status"] = _status(out)
            return out
    except json.JSONDecodeError:
        pass

    # JSONL（stream-json）
    events = 0
    tool_calls = 0
    tool_names = []
    result_ev = None
    actual_model = None
    for line in stripped.splitlines():
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        events += 1
        for b in _blocks(ev.get("message")):
            if isinstance(b, dict) and b.get("type") == "tool_use":
                tool_calls += 1
                tool_names.append(b.get("name", "?"))
        if ev.get("type") == "system" and ev.get("subtype") == "init":
            actual_model = ev.get("model") or actual_model
        if ev.get("type") == "result":
            result_ev = ev
    if events == 0:
        return out
    out["format"] = "stream-json"
    out["actual_model"] = actual_model
    out["tool_calls"] = tool_calls
    out["tool_names"] = tool_names
    if result_ev is not None:
        _fill_result(out, result_ev)
        out["status"] = _status(out)
    else:
        out["status"] = "no_result_event"
    return out


def _status(out):
    """`is_error` を成功扱いにしない。

    API エラーは本文にエラー説明が入って返ることがあり、本文の有無だけで判定すると
    **エラー応答が完了ゲートを通過してしまう**。回答としては空と同じ扱いにする。
    """
    if out.get("is_error") is True:
        return "error_result"
    if not out["result"]:
        return "empty_result"
    return "ok"


def denied_tools(out):
    """permission_denials から拒否されたツール名を取り出す（形が変わっても落ちないように）。"""
    names = []
    for d in out.get("permission_denials") or []:
        if isinstance(d, dict):
            names.append(d.get("tool_name") or d.get("name") or "?")
        elif isinstance(d, str):
            names.append(d)
    return names


def _fill_result(out, ev):
    out["result"] = ev.get("result") or ""
    out["cost_usd"] = ev.get("total_cost_usd")
    out["duration_ms"] = ev.get("duration_ms")
    out["usage"] = ev.get("usage")
    out["num_turns"] = ev.get("num_turns")
    out["permission_denials"] = ev.get("permission_denials")
    out["is_error"] = ev.get("is_error")
    out["session_id"] = ev.get("session_id")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--out")
    a = ap.parse_args()
    text = pathlib.Path(a.raw).read_text(encoding="utf-8", errors="replace")
    d = parse(text)
    payload = json.dumps(d, ensure_ascii=False, indent=2)
    if a.out:
        pathlib.Path(a.out).write_text(payload, encoding="utf-8")
    else:
        print(payload)
    return 0 if d["status"] == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
