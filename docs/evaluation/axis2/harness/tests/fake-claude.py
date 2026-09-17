#!/usr/bin/env python3
"""配管テスト用の偽 `claude`。**モデルを呼ばない＝無料。**

CLAUDE_BIN にこれを指すと、prepare → run → grade-pairwise → analyze の全経路を
課金なしで通せる。実形の JSON を模しているので、パーサ・写像・集計・凍結・
ランダム化・人間確認の抽出まで一通り検査できる。

判定結果は fixture タスクの id で決め打ちにしてあり、次の3経路を作る。
  f01 … 2判定が一致（B勝ち）
  f02 … 左右入替で不一致（unresolved → 人間確認へ）
  f03 … A に critical error（→ B勝ち＋critical 記録）
"""
import json
import os
import re
import sys

B_MARK = "[[B-PROMPT]]"


def argval(argv, name):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


DISPLAY = {"fable": "Fable 5.1", "opus": "Opus 5", "sonnet": "Sonnet 5"}
MODEL_ID = {"fable": "claude-fable-5-1", "opus": "claude-opus-5",
            "sonnet": "claude-sonnet-5"}


def emit(result, tool_calls=0, cost=0.0123, duration=4567, turns=1, model=None):
    # 実モデル ID は system/init に出る。v3 はこれを指定と突き合わせる。
    init = {"type": "system", "subtype": "init", "session_id": "fake-session"}
    if model:
        init["model"] = model
    print(json.dumps(init, ensure_ascii=False))
    for i in range(tool_calls):
        print(json.dumps({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "id": f"tu_{i}", "name": "Read", "input": {}}]}},
            ensure_ascii=False))
    print(json.dumps({"type": "assistant", "message": {"content": [
        {"type": "text", "text": result}]}}, ensure_ascii=False))
    print(json.dumps({
        "type": "result", "subtype": "success", "is_error": False,
        "result": result, "total_cost_usd": cost, "duration_ms": duration,
        "num_turns": turns, "permission_denials": [],
        "usage": {"input_tokens": 10, "output_tokens": 100},
        "session_id": "fake-session"}, ensure_ascii=False))


def fixture_id(text):
    m = re.search(r"\[\[FIXTURE:(\w+)\]\]", text or "")
    return m.group(1) if m else "f00"


def side_of(prompt, tag_open, tag_close):
    m = re.search(re.escape(tag_open) + r"(.*?)" + re.escape(tag_close),
                  prompt, re.S)
    return m.group(1) if m else ""


def main() -> int:
    argv = sys.argv[1:]
    if "--version" in argv:
        print("fake-claude 0.0.0 (plumbing test)")
        return 0
    prompt = argval(argv, "-p") or ""

    # --- judge ---
    if "判定の優先順位" in prompt:
        fid = fixture_id(prompt)
        left = side_of(prompt, "<左の回答>", "</左の回答>")
        right = side_of(prompt, "<右の回答>", "</右の回答>")
        # context_required=true のタスクは実装照合版のテンプレートで来る＝ツールが使える
        with_ctx = "Read` / `Grep` / `Glob` で実装を読めます" in prompt
        n_tools = 4 if with_ctx else 0
        left_is_b = "GEN=B" in left
        right_is_b = "GEN=B" in right
        if fid == "f01":                      # 2判定とも B 勝ち
            v = "left_better" if left_is_b else "right_better"
        elif fid == "f02":                    # 位置バイアスを模して常に「右」
            v = "right_better"
        elif fid == "f03":                    # A 側に重大な誤り
            v = "critical_error_left" if right_is_b else "critical_error_right"
        elif fid == "f04":                    # B 勝ち（Codex 側は A 勝ちにして不一致を作る）
            v = "left_better" if left_is_b else "right_better"
        else:
            v = "tie"
        emit(json.dumps({"verdict": v, "reason": f"fixture {fid} の決め打ち",
                         "evidence": f"左: {left[:20]} ／ 右: {right[:20]}"},
                        ensure_ascii=False), cost=0.02, tool_calls=n_tools)
        return 0

    # --- which-model フェーズ2（縮退経路の2往復目） ---
    if "--resume" in argv:
        # 実物と同じ形で確定モデルを表示する（check_b_prompt.py がここを読む）
        m = re.match(r"p model (\S+)\s+(\S+)", prompt.strip())
        alias, effort = (m.group(1), m.group(2)) if m else ("sonnet", "medium")
        name = DISPLAY.get(alias, alias)
        emit(f"確定モデル：{name} / effort={effort}\n\n最適化後プロンプト：\n"
             f"{B_MARK} これは which-model が整形した想定のプロンプト本文です。\n"
             "主な調整点：fixture のため固定文言。", cost=0.05, tool_calls=2, turns=3)
        return 0

    # --- which-model フェーズ1 ---
    if prompt.startswith("/which-model:pick"):
        emit("推奨：Fixture 5 / effort=high\n"
             "▶ p：最適化プロンプトを表示　▶ p model <モデル> [<effort>]　▶ n：中止",
             cost=0.03, tool_calls=1, turns=2)
        return 0

    # --- 回答の実行 ---
    fid = fixture_id(prompt)
    arm = "B" if B_MARK in prompt else "A"
    tools = 0 if argval(argv, "--tools") == "" else 3
    asked = argval(argv, "--model") or ""
    # FAKE_MODEL_DRIFT を立てると別モデルで走ったことにする（model_mismatch の検査用）
    actual = os.environ.get("FAKE_MODEL_DRIFT") or asked
    emit(f"GEN={arm} FIXTURE={fid}\n"
         f"これは {arm} 腕の回答本文（fixture）。ツール {tools} 回。",
         cost=0.4 if arm == "A" else 0.3, tool_calls=tools, turns=tools + 1,
         duration=30000 if arm == "A" else 25000, model=actual)
    return 0


if __name__ == "__main__":
    sys.exit(main())
