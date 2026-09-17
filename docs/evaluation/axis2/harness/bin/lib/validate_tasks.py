#!/usr/bin/env python3
"""tasks.json の実行条件を機械検査する（DESIGN.md §4）。違反があれば非ゼロ終了。

使い方: validate_tasks.py
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402

REQUIRED = ("id", "target_model", "target_effort", "workdir",
            "allowed_tools", "context_required", "text", "model_id")
MODELS = {"opus", "sonnet", "fable", "haiku"}
EFFORTS = {"low", "medium", "high", "xhigh", "max"}
# エイリアス → 期待するフル ID。回答実行はエイリアスに任せない（S142）。
EXPECT_ID = {"fable": "claude-fable-5-1", "opus": "claude-opus-5",
             "sonnet": "claude-sonnet-5", "haiku": "claude-haiku-4-5"}


def main() -> int:
    errs, warns = [], []
    ts = common.tasks()
    if not ts:
        errs.append("tasks.json にタスクが1件もない")
    seen = set()
    for t in ts:
        tid = t.get("id", "<no id>")
        for k in REQUIRED:
            if k not in t:
                errs.append(f"{tid}: 必須フィールド {k} が無い")
        if tid in seen:
            errs.append(f"{tid}: id が重複している")
        seen.add(tid)
        if t.get("target_model") not in MODELS:
            errs.append(f"{tid}: target_model が不正: {t.get('target_model')}")
        if t.get("target_effort") not in EFFORTS:
            errs.append(f"{tid}: target_effort が不正: {t.get('target_effort')}")
        if not (t.get("text") or "").strip():
            errs.append(f"{tid}: text が空")
        mid = t.get("model_id")
        want = EXPECT_ID.get(t.get("target_model"))
        if not mid:
            errs.append(f"{tid}: model_id が無い")
        elif want and mid != want:
            # 一致しない場合は事故ではなく意図的な差し替え（プローブ失敗時の Fable 5 落とし等）
            # のことがあるので警告にとどめ、REPORT へ出させる。
            warns.append(f"{tid}: model_id が既定と違う（{mid}。既定は {want}）"
                          "— 意図的なら plan と REPORT に記録すること")

        cr = t.get("context_required")
        wd = t.get("workdir")
        tools = t.get("allowed_tools")
        if not isinstance(tools, list):
            errs.append(f"{tid}: allowed_tools は配列であること")
            continue
        if cr is True:
            if wd == "sandbox":
                errs.append(f"{tid}: context_required=true なのに workdir が sandbox")
            elif not pathlib.Path(wd).is_dir():
                errs.append(f"{tid}: workdir が存在しない: {wd}")
            if not tools:
                errs.append(f"{tid}: context_required=true なのに allowed_tools が空")
        elif cr is False:
            if wd != "sandbox":
                errs.append(f'{tid}: context_required=false なら workdir は "sandbox" にする'
                            f"（今: {wd}）")
            if tools:
                errs.append(f"{tid}: context_required=false なのに allowed_tools が空でない")
        else:
            errs.append(f"{tid}: context_required は true/false のいずれか")

    n = len(ts)
    if n < 8:
        warns.append(f"実課題が {n} 件しかない（目標 8〜10）。"
                     "TASKS-NEEDED.md を利用者へ渡すこと。不足のまま走らせてもよいが、"
                     "停止規則1（B勝ち3件未満）に届かない可能性が構造的に高い")

    for w in warns:
        print(f"WARN: {w}", file=sys.stderr)
    for e in errs:
        print(f"ERROR: {e}", file=sys.stderr)
    if errs:
        return 1
    print(f"validate: ok（{n} tasks）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
