#!/usr/bin/env python3
"""blind pairwise の judge プロンプトを組み立てる。

使い方:
  build_judge_prompt.py <task_id> <rep> <order> [family]  … プロンプトを stdout へ
  build_judge_prompt.py --env <task_id>                  … judge の実行条件を KEY=VALUE で出力

family は claude（既定）か codex。テンプレートの系統を切り替えるだけで、
判定の優先順位・禁止事項・verdict の語彙は同一である。

order は「左に置く腕」→「右に置く腕」。judge には腕ラベルも使用プロンプトも
which-model の存在も渡さない。渡すのは依頼文と2つの回答本文だけ。

**context_required=true のタスクは、回答者と同じ workdir・同じ read-only ツールで
判定させる**（DESIGN.md §7）。材料を与えないと judge は実装との一致を確認できず、
文章の説得力・網羅性しか比べられない。テンプレートも専用のものへ切り替える。
"""
import json
import pathlib
import shlex
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402


def output_text(task_id, arm, rep):
    p = common.AX / "outputs" / f"{task_id}_{arm}_r{rep}.json"
    if not p.exists():
        raise SystemExit(f"ERROR: 出力が無い: {p}")
    d = json.loads(p.read_text(encoding="utf-8"))
    if d.get("status") != "ok":
        raise SystemExit(f"ERROR: status={d.get('status')}: {p}")
    return d["result"]


def template_for(task, family="claude"):
    """judge 系統ごとのテンプレート。中身は同一で、ツールの言い方と出力指示だけ違う。"""
    base = ("judge_prompt_context" if task["context_required"] else "judge_prompt")
    name = base + ("_codex.txt" if family == "codex" else ".txt")
    return (common.AX / "bin" / "lib" / name).read_text(encoding="utf-8")


def main() -> int:
    if sys.argv[1] == "--env":
        task = common.task_by_id()[sys.argv[2]]
        # judge の workdir とツールは回答時と同じにする（context_required=false は空 sandbox）
        wd = common.resolve_workdir(task) if task["context_required"] else common.sandbox()
        tools = task["allowed_tools"] if task["context_required"] else []
        print(f"JUDGE_WORKDIR={shlex.quote(str(wd))}")
        print(f"JUDGE_TOOLS={shlex.quote(' '.join(tools))}")
        return 0

    task_id, rep, order = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    if order not in ("AB", "BA"):
        raise SystemExit("ERROR: order は AB か BA")
    family = sys.argv[4] if len(sys.argv) > 4 else "claude"
    task = common.task_by_id()[task_id]
    left_arm, right_arm = order[0], order[1]
    body = (template_for(task, family)
            .replace("{{TASK}}", task["text"])
            .replace("{{LEFT}}", output_text(task_id, left_arm, rep))
            .replace("{{RIGHT}}", output_text(task_id, right_arm, rep)))
    sys.stdout.write(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
