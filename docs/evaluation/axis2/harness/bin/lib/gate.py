#!/usr/bin/env python3
"""完了ゲート（STOP-RULES.md §0-2）。予定件数に足りなければ非ゼロ終了する。

使い方: gate.py {gen|run|judge|judge2}

実行・採点スクリプトは失敗を WARN で記録して先へ進む（再開しやすくするため）。
このゲートが無いと、API 障害で run が欠けただけで「B勝ち3件未満 ＝ 価値信号なし」に
落ちる。**装置の失敗を製品の評価に化けさせない**ためのもの。
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402


def main() -> int:
    stage = sys.argv[1]
    ax = common.AX
    plan = json.loads((ax / "plan.json").read_text(encoding="utf-8"))
    tasks = common.tasks()
    reps = range(1, int(plan["reps"]) + 1)
    missing = []

    if stage == "gen":
        for t in tasks:
            for r in reps:
                if not (ax / "prompts" / "B" / f"{t['id']}_r{r}.txt").is_file():
                    missing.append(f"prompts/B/{t['id']}_r{r}.txt")
        label = "B プロンプト生成"
    elif stage == "run":
        for t in tasks:
            for a in ("A", "B"):
                for r in reps:
                    p = ax / "outputs" / f"{t['id']}_{a}_r{r}.json"
                    if not p.is_file():
                        missing.append(f"outputs/{p.name}（未実行）")
                    else:
                        d = json.loads(p.read_text(encoding="utf-8"))
                        if d["status"] != "ok":
                            extra = ""
                            if d["status"] in ("model_mismatch", "actual_model_unknown"):
                                extra = (f"：期待 {d.get('expect_model')} / "
                                         f"実測 {d.get('actual_model')}")
                            missing.append(f"outputs/{p.name}（status={d['status']}{extra}）")
        label = "回答の実行"
    elif stage in ("judge", "judge2"):
        d = "judgements" if stage == "judge" else "judgements2"
        for unit, orders in plan["judge_orders"].items():
            for seq, o in enumerate(orders, 1):
                p = ax / d / f"{unit}_{seq}_{o}.json"
                if not p.is_file():
                    missing.append(f"{d}/{p.name}")
        label = ("pairwise 判定（Claude）" if stage == "judge"
                 else "pairwise 判定（Codex・第2 judge）")
    else:
        print(f"ERROR: 未知の stage: {stage}", file=sys.stderr)
        return 2

    if missing:
        print(f"\n未完了：{label} が {len(missing)} 件欠けている", file=sys.stderr)
        for m in missing[:20]:
            print(f"  - {m}", file=sys.stderr)
        if len(missing) > 20:
            print(f"  … 他 {len(missing) - 20} 件", file=sys.stderr)
        print("\n同じコマンドを再実行すれば欠けた分だけ埋まる（冪等）。"
              "\n**欠けたまま先へ進まないこと。** 装置の失敗が「価値信号なし」に化ける"
              "（STOP-RULES.md §0-2）。", file=sys.stderr)
        return 1
    print(f"完了ゲート[{stage}]: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
