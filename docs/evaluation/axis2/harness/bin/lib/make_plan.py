#!/usr/bin/env python3
"""実行計画（plan.json）を seed から決定論的に作る（DESIGN.md §6）。

使い方: make_plan.py

決めるもの（すべて実行前に凍結する）:
- B プロンプトの生成順（タスク×反復のシャッフル）
- 回答の実行順（タスク×腕×反復のシャッフル。A→B の固定順を廃止）
- pairwise の提示順（比較単位ごとに1回目をコイン投げ、2回目はその反転）
- 人間確認の無作為抽出（全比較単位の human_sample_rate）
- 各 workdir の git HEAD / dirty 状態（実行時に一致を確認するため）

既に plan.json があれば作り直さない（冪等）。作り直したいときは削除してから実行する。
"""
import datetime
import hashlib
import json
import pathlib
import random
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402


def git_state(path: pathlib.Path):
    if not (path / ".git").exists():
        return {"vcs": "none"}
    try:
        head = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                              cwd=path, capture_output=True, text=True,
                              check=True).stdout.strip()
        porcelain = subprocess.run(["git", "status", "--porcelain"],
                                   cwd=path, capture_output=True, text=True,
                                   check=True).stdout.strip()
        # dirty かどうかだけでなく、変更されているファイルの一覧も指紋にする。
        # **限界：既に変更済みのファイルの中身をさらに書き換えても検出できない。**
        # 確実に揃えたいなら、実行前に commit / stash して clean にすること。
        return {"vcs": "git", "head": head, "dirty": bool(porcelain),
                "porcelain_sha256": hashlib.sha256(
                    porcelain.encode("utf-8")).hexdigest()[:16]}
    except (subprocess.CalledProcessError, OSError) as e:
        return {"vcs": "git", "error": str(e)}


def main() -> int:
    ax = common.AX
    plan_path = ax / "plan.json"
    cfg = common.config()
    tasks = common.tasks()
    if plan_path.exists():
        old = json.loads(plan_path.read_text(encoding="utf-8"))
        ids = [t["id"] for t in tasks]
        if set(old["tasks"]) != set(ids) or old.get("reps") != cfg["reps"]:
            print("ERROR: plan.json とタスク構成が食い違っている。\n"
                  f"  plan: {sorted(old['tasks'])} / reps={old.get('reps')}\n"
                  f"  now : {sorted(ids)} / reps={cfg['reps']}\n"
                  "タスクを足した／減らしたときは plan.json を削除してから prepare.sh を"
                  "実行すること（既存の B プロンプトは再利用されるので作り直しは起きない）。",
                  file=sys.stderr)
            return 1
        print("plan: exists（作り直さない）")
        return 0
    reps = list(range(1, int(cfg["reps"]) + 1))
    rnd = random.Random(cfg["seed"])

    gen_order = [{"task": t["id"], "rep": r} for t in tasks for r in reps]
    rnd.shuffle(gen_order)

    run_order = [{"task": t["id"], "arm": a, "rep": r}
                 for t in tasks for a in ("A", "B") for r in reps]
    rnd.shuffle(run_order)

    units = [common.unit_id(t["id"], r) for t in tasks for r in reps]
    judge_orders = {}
    for u in sorted(units):
        first = "AB" if rnd.random() < 0.5 else "BA"
        judge_orders[u] = [first, "BA" if first == "AB" else "AB"]

    # 人間確認の盲検割当。judge の左右割当とは**別の抽選**にする
    # （同じにすると、提示順から腕を推測できてしまう）
    blind_map = {}
    for u in sorted(units):
        blind_map[u] = "AB" if rnd.random() < 0.5 else "BA"

    k = max(1, round(len(units) * float(cfg["human_sample_rate"]))) if units else 0
    human_sample = sorted(rnd.sample(sorted(units), k)) if k else []

    workdir_state = {}
    for t in tasks:
        wd = common.resolve_workdir(t)
        workdir_state[str(wd)] = git_state(wd)

    plan = {
        "created_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "seed": cfg["seed"],
        "reps": cfg["reps"],
        "human_sample_rate": cfg["human_sample_rate"],
        "tasks": [t["id"] for t in tasks],
        "n_tasks": len(tasks),
        "n_units": len(units),
        "n_runs": len(run_order),
        "n_judgements": len(units) * 2,
        "workdir_state": workdir_state,
        "gen_order": gen_order,
        "run_order": run_order,
        "judge_orders": judge_orders,
        "_blind_map_note": "人間確認の X/Y 割当。'AB' は X=A・Y=B、'BA' は X=B・Y=A。"
                           "確認前に見ないこと。",
        "blind_map": blind_map,
        "human_sample": human_sample,
    }
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2),
                         encoding="utf-8")
    print(f"plan: {len(tasks)} tasks / {len(run_order)} runs / "
          f"{len(units) * 2} judgements / human sample {len(human_sample)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
