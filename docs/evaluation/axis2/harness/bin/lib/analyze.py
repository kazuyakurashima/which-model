#!/usr/bin/env python3
"""集計して results.csv / REPORT.md / human-review.md を出す（v3・DESIGN.md §4・§5）。

v2 からの違い：
- **judge が2系統ある**（Claude=J1 / Codex=J2）。両者が一致した比較単位は自動確定し、
  **割れた比較単位だけ**を人間確認へ回す。無作為抽出は廃止した。
- **critical error は両 judge が同じ腕に報告したときだけ「確定」**とし、規則3に使う。
  片方だけの報告は「未確定」として件数を出すだけ。
- **停止規則4は judge 間の食い違い率**。該当したときの結論は「判定不能」であって
  「価値信号なし」ではない（判定装置が信頼できないことと、製品に価値が無いことは別）。

統計検定は使わない。数えるのはタスク単位の勝敗だけ。
完了ゲート（run / judge / judge2 / 不一致分の人間確認）を先に見る。
"""
import csv
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402

AX = common.AX
FAMILIES = (("claude", "judgements"), ("codex", "judgements2"))


def load_plan():
    return json.loads((AX / "plan.json").read_text(encoding="utf-8"))


def load_runs():
    runs = {}
    for p in sorted((AX / "outputs").glob("*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        runs[(d["task_id"], d["arm"], d["rep"])] = d
    return runs


def load_judgements(subdir):
    js = {}
    for p in sorted((AX / subdir).glob("*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        js.setdefault((d["task_id"], d["rep"]), []).append(d)
    return js


def load_human(blind_map):
    """人間確認を読む。**盲検（X/Y）でしか受け付けない**。"""
    h, errors = {}, []
    d = AX / "human"
    if d.is_dir():
        for p in sorted(d.glob("*.json")):
            rec = json.loads(p.read_text(encoding="utf-8"))
            w = rec.get("winner")
            if w in ("A", "B"):
                errors.append(f"{p.name}: winner に腕（{w}）が書かれている。"
                              "盲検が破れているので集計に使わない。X / Y / tie で書くこと")
                continue
            if w not in ("X", "Y", "tie", None):
                errors.append(f"{p.name}: winner が不正（{w}）。X / Y / tie のいずれか")
                continue
            order = blind_map.get(p.stem)
            if w in ("X", "Y") and not order:
                errors.append(f"{p.name}: plan.json に blind_map が無い比較単位")
                continue
            rec["winner_arm"] = ("tie" if w == "tie" else
                                 (None if w is None else
                                  (order[0] if w == "X" else order[1])))
            ce = rec.get("critical_error")
            if ce in ("X", "Y"):
                rec["critical_error_arm"] = order[0] if ce == "X" else order[1]
            elif ce in (None, "none"):
                rec["critical_error_arm"] = "none" if ce == "none" else None
            else:
                errors.append(f"{p.name}: critical_error が不正（{ce}）。X / Y / none")
                continue
            h[p.stem] = rec
    return h, errors


def resolve_family(judgs):
    """1系統の judge の確定勝者。左右入替2判定が一致したときだけ確定する。"""
    if len(judgs) < 2:
        return {"winner": "unresolved", "why": f"判定が{len(judgs)}件しかない",
                "verdicts": [j["verdict"] for j in judgs],
                "tool_calls": [j.get("judge_tool_calls") for j in judgs],
                "critical": sorted({j["critical_error_arm"] for j in judgs
                                    if j["critical_error_arm"]})}
    winners = [j["winner_arm"] for j in judgs[:2]]
    critical = sorted({j["critical_error_arm"] for j in judgs if j["critical_error_arm"]})
    base = {"verdicts": [j["verdict"] for j in judgs],
            "tool_calls": [j.get("judge_tool_calls") for j in judgs],
            "critical": critical}
    if winners[0] == winners[1]:
        return {"winner": winners[0], "why": "2判定が一致", **base}
    return {"winner": "unresolved", "why": f"左右入替で不一致: {winners}", **base}


TASK_RULE = {
    frozenset(["B"]): "B",
    frozenset(["A"]): "A",
    frozenset(["tie"]): "tie",
    frozenset(["B", "tie"]): "B",
    frozenset(["A", "tie"]): "A",
    frozenset(["A", "B"]): "reversal",
}


def task_winner(unit_winners):
    if any(w in ("unresolved", None) for w in unit_winners):
        return "pending"
    return TASK_RULE.get(frozenset(unit_winners), "pending")


def fmt(x, nd=3):
    return "—" if x is None else f"{x:.{nd}f}"


def _sum(vals):
    v = [x for x in vals if x is not None]
    return sum(v) if v else None


def _diff(x, y):
    return None if x is None or y is None else x - y


def main() -> int:
    plan = load_plan()
    tasks = common.tasks()
    runs = load_runs()
    per_family = {fam: load_judgements(sub) for fam, sub in FAMILIES}
    blind_map = plan.get("blind_map", {})
    human, human_errors = load_human(blind_map)
    for e in human_errors:
        print(f"ERROR: {e}", file=sys.stderr)

    # ---- results.csv ----
    cols = ["task_id", "arm", "rep", "model", "expect_model", "actual_model", "effort",
            "status", "workdir", "allowed_tools", "output_chars", "tool_calls",
            "num_turns", "answer_cost_usd", "gen_cost_usd", "total_cost_usd",
            "answer_duration_ms", "gen_duration_ms", "total_duration_ms",
            "elapsed_s", "prompt_chars", "prompt_sha256"]
    with (AX / "results.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for k in sorted(runs):
            w.writerow(runs[k])

    # ---- 比較単位 ----
    units = []
    for t in tasks:
        for rep in range(1, int(plan["reps"]) + 1):
            uid = common.unit_id(t["id"], rep)
            fam = {}
            for name, _ in FAMILIES:
                js = sorted(per_family[name].get((t["id"], rep), []),
                            key=lambda d: d["order"])
                fam[name] = resolve_family(js)
            j1, j2 = fam["claude"]["winner"], fam["codex"]["winner"]
            agree = (j1 == j2 and j1 in ("A", "B", "tie"))

            # critical は両系統が同じ腕に報告したときだけ「確定」
            c1, c2 = set(fam["claude"]["critical"]), set(fam["codex"]["critical"])
            confirmed_crit = sorted(c1 & c2)
            unconfirmed_crit = sorted(c1 ^ c2)

            hv = human.get(uid)
            if agree:
                final, need_human = j1, False
            elif hv and hv.get("winner_arm") in ("A", "B", "tie"):
                final, need_human = hv["winner_arm"], False
            else:
                final, need_human = None, True

            if hv and hv.get("critical_error_arm") is not None:
                ce = hv["critical_error_arm"]
                confirmed_crit = [] if ce == "none" else [ce]
                unconfirmed_crit = []

            units.append({
                "unit": uid, "task": t["id"], "rep": rep,
                "context_required": t["context_required"],
                "j1": j1, "j1_why": fam["claude"]["why"],
                "j1_verdicts": fam["claude"]["verdicts"],
                "j1_tools": fam["claude"]["tool_calls"],
                "j1_n": len(per_family["claude"].get((t["id"], rep), [])),
                "j2": j2, "j2_why": fam["codex"]["why"],
                "j2_verdicts": fam["codex"]["verdicts"],
                "j2_tools": fam["codex"]["tool_calls"],
                "j2_n": len(per_family["codex"].get((t["id"], rep), [])),
                "agree": agree,
                "human_winner": hv.get("winner") if hv else None,
                "human_note": hv.get("note") if hv else None,
                "final_winner": final,
                "need_human": need_human,
                "critical": confirmed_crit,
                "critical_unconfirmed": unconfirmed_crit,
                "workdir": str(common.resolve_workdir(t)),
            })

    # ---- タスク単位 ----
    by_task = {}
    for u in units:
        by_task.setdefault(u["task"], []).append(u)
    task_rows = []
    for t in tasks:
        us = sorted(by_task.get(t["id"], []), key=lambda x: x["rep"])
        ws = [u["final_winner"] or "unresolved" for u in us]
        task_rows.append({"task": t["id"], "unit_winners": ws,
                          "winner": task_winner(ws)})
    counts = {k: sum(1 for r in task_rows if r["winner"] == k)
              for k in ("A", "B", "tie", "reversal", "pending")}

    crit_count = {"A": 0, "B": 0}
    for u in units:
        for a in set(u["critical"]):
            if a in crit_count:
                crit_count[a] += 1
    crit_unconf = {"A": 0, "B": 0}
    for u in units:
        for a in set(u["critical_unconfirmed"]):
            if a in crit_unconf:
                crit_unconf[a] += 1

    # ---- judge 間の一致（停止規則4） ----
    judged = [u for u in units if u["j1_n"] >= 2 and u["j2_n"] >= 2]
    disagree = [u for u in judged if not u["agree"]]
    dis_rate = (len(disagree) / len(judged)) if judged else None

    # ---- コスト・時間 ----
    agg = {}
    for arm in ("A", "B"):
        rs = [r for r in runs.values() if r["arm"] == arm and r["status"] == "ok"]
        agg[arm] = {
            "n": len(rs),
            "cost": _sum(r.get("total_cost_usd") for r in rs),
            "answer_cost": _sum(r.get("answer_cost_usd") for r in rs),
            "gen_cost": _sum(r.get("gen_cost_usd") for r in rs),
            "ms": _sum(r.get("total_duration_ms") for r in rs),
            "chars": _sum(r.get("output_chars") for r in rs),
            "tools": _sum(r.get("tool_calls") for r in rs),
        }
    judge_cost = {}
    for name, sub in FAMILIES:
        vals = [j.get("judge_cost_usd") for v in per_family[name].values() for j in v]
        judge_cost[name] = (_sum(vals), sum(len(v) for v in per_family[name].values()))

    # ---- 人間確認（盲検 X/Y）。不一致分だけ ----
    need = [u for u in units if u["need_human"]]
    by_id = common.task_by_id()
    for u in need:
        order = blind_map.get(u["unit"])
        if not order:
            continue
        d = AX / "review" / u["unit"]
        d.mkdir(parents=True, exist_ok=True)
        task_text = by_id[u["task"]]["text"]
        for label, arm in (("X", order[0]), ("Y", order[1])):
            r = runs.get((u["task"], arm, u["rep"]))
            if not r:
                continue
            (d / f"{label}.md").write_text(
                f"# 回答 {label}\n\n## 依頼\n\n```\n{task_text}\n```\n\n"
                f"## 回答\n\n{r['result']}\n", encoding="utf-8")

    hr = ["# 人間が確認する比較（自動抽出・盲検）", "",
          "**抽出条件は1つだけ：2系統の judge（Claude / Codex）が同じ勝者を指さなかった比較。**",
          "どちらかが左右入替で割れた場合（`unresolved`）も含む。無作為抽出は v3 では行わない",
          "（DESIGN.md §4）。**これ以外は見ない。**", "",
          f"対象 {len(need)} 件（全 {len(units)} 比較単位中）。", "",
          "## 手順", "",
          "1. `review/<unit>/X.md` と `Y.md` だけを読む。",
          "   **どちらが which-model 版かは伏せてある**（`plan.json` の `blind_map` を先に見ないこと）。",
          "2. 「リポジトリ」欄があるものは、**そのリポジトリを開いて実装と照合する**",
          "   （回答の断定が実装と一致するか。judge にも同じ材料を与えてある）。",
          "3. `human/<unit>.json` に結果を置き、`bin/analyze.sh` を再実行する。", "",
          '```json',
          '{"winner": "X", "note": "理由", "critical_error": "none"}',
          '```', "",
          "`winner` は `X` / `Y` / `tie`。`critical_error` は任意（`X` / `Y` / `none`）。",
          "**`A` / `B` と書いたものは盲検が破れている証拠として集計側が弾く。**", ""]
    for u in need:
        hr += [f"## {u['unit']}", "",
               f"- 理由: judge 間の不一致（系統1: {u['j1']} ／ 系統2: {u['j2']}）",
               f"- 読むもの: `review/{u['unit']}/X.md` と `review/{u['unit']}/Y.md`"]
        if u["context_required"]:
            hr += [f"- **リポジトリ（実装と照合する）**: `{u['workdir']}`"]
        else:
            hr += ["- リポジトリ: なし（自己完結した質問）"]
        hr += [""]
    (AX / "human-review.md").write_text("\n".join(hr), encoding="utf-8")

    # ---- 完了ゲート ----
    exp_runs = len(tasks) * 2 * int(plan["reps"])
    ok_runs = sum(1 for r in runs.values() if r["status"] == "ok")
    bad_model = [k for k, r in runs.items()
                 if r.get("status") in ("model_mismatch", "actual_model_unknown")]
    exp_judg = len(units) * 2
    gaps = []
    if ok_runs < exp_runs:
        gaps.append(f"run が {ok_runs}/{exp_runs} 件（status=ok のみ計上）")
    if bad_model:
        gaps.append(f"指定と違うモデルで走った run が {len(bad_model)} 件")
    for name, sub in FAMILIES:
        got = sum(len(v) for v in per_family[name].values())
        if got < exp_judg:
            gaps.append(f"{sub} の判定が {got}/{exp_judg} 件")
    if need:
        gaps.append(f"judge 間の不一致 {len(need)} 件が未確認（`human-review.md`）")
    if human_errors:
        gaps.append(f"人間確認の記法エラーが {len(human_errors)} 件（盲検が破れている可能性）")
    complete = not gaps

    # ---- 停止規則 ----
    rules = [
        ("1. B勝ちタスク数が3件未満", counts["B"] < 3, f"B勝ち {counts['B']} 件"),
        ("2. B勝ち数が A勝ち数以下", counts["B"] <= counts["A"],
         f"B {counts['B']} / A {counts['A']}"),
        ("3. B だけに確定した重大な正確性低下が複数（B≥2 かつ B>A）",
         crit_count["B"] >= 2 and crit_count["B"] > crit_count["A"],
         f"確定 critical error B {crit_count['B']} / A {crit_count['A']}"),
    ]
    r4_hit = bool(dis_rate is not None and dis_rate > 1 / 3)
    rules.append(("4. judge 間の食い違い率が 1/3 超（→ 判定不能）", r4_hit,
                  (f"{len(judged)} 単位中 不一致 {len(disagree)} 件"
                   + (f"（{dis_rate:.0%}）" if dis_rate is not None else ""))))
    triggered = [r for r in rules if r[1]]

    # ---- REPORT.md ----
    n_ok = ok_runs
    n_j1 = sum(len(v) for v in per_family["claude"].values())
    n_j2 = sum(len(v) for v in per_family["codex"].values())
    lines = [
        "# 軸2 v3 集計結果", "",
        ("**状態：INCOMPLETE / 判定保留**" if not complete else "**状態：完了**"), "",
        f"タスク {len(tasks)} 件 ／ 反復 {plan['reps']} ／ run {len(runs)}（成功 {n_ok}）"
        f" ／ 判定 Claude {n_j1} ・ Codex {n_j2}", "",
    ]
    lines += [
        "> 統計検定は使っていない（標本が少なすぎる）。数え上げだけを見ること。",
        "> **同一タスクの反復を独立タスクとして数えていない。**", "",
        "## 1. タスク単位の勝敗", "",
        "| タスク | 反復ごとの勝者 | タスクの勝者 |", "| --- | --- | --- |",
    ]
    for r in task_rows:
        lines.append(f"| {r['task']} | {' / '.join(r['unit_winners'])} | **{r['winner']}** |")
    lines += ["",
              f"**B勝ち {counts['B']} ／ A勝ち {counts['A']} ／ 引き分け {counts['tie']} "
              f"／ 反転 {counts['reversal']} ／ 保留 {counts['pending']}**", ""]
    if counts["reversal"]:
        rev = [r["task"] for r in task_rows if r["winner"] == "reversal"]
        lines += [f"反復間で勝敗が逆転したタスク: {', '.join(rev)}",
                  "**反転は B勝ちに数えない。**", ""]

    lines += ["## 2. judge 間の一致（Claude / Codex）", "",
              "**2系統が同じ勝者を指した比較単位は自動確定**し、割れた分だけ人間が盲検で見る"
              "（DESIGN.md §4）。", "",
              "| | 件数 |", "| --- | ---: |",
              f"| 両系統の判定が揃った比較単位 | {len(judged)} |",
              f"| うち一致（自動確定） | {len(judged) - len(disagree)} |",
              f"| うち不一致（人間確認へ） | {len(disagree)} |",
              f"| 一致率 | {'—' if dis_rate is None else f'{1 - dis_rate:.0%}'} |", ""]
    if disagree:
        lines += ["不一致の内訳：", ""]
        for u in disagree:
            lines.append(f"- `{u['unit']}` … Claude: {u['j1']}（{u['j1_why']}）"
                         f" ／ Codex: {u['j2']}（{u['j2_why']}）")
        lines += [""]

    lines += ["## 3. critical error", "",
              "**両系統が同じ腕に報告したものだけを「確定」とし、停止規則3に使う。**", "",
              "| 腕 | 確定 | 片方だけ（未確定） |", "| --- | ---: | ---: |",
              f"| A（素の依頼） | {crit_count['A']} | {crit_unconf['A']} |",
              f"| B（which-model） | {crit_count['B']} | {crit_unconf['B']} |", ""]

    ctx = [u for u in units if u["context_required"]]
    zero1 = [u for u in ctx if any(not t for t in u["j1_tools"])]
    zero2 = [u for u in ctx if any(not t for t in u["j2_tools"])]
    lines += ["## 4. judge が実装を確認したか", "",
              "`context_required=true` の判定は、回答者と同じ workdir と読み取り専用の道具で行う。",
              "**ツール使用0回の判定は採用せずリトライさせている**（判定失敗扱い）ので、"
              "ここに残るものは装置の異常である。", "",
              f"- 対象の比較単位: {len(ctx)} 件",
              f"- Claude 側でツール0回を含む: {len(zero1)} 件"
              + (f"（{', '.join(u['unit'] for u in zero1)}）" if zero1 else ""),
              f"- Codex 側でツール0回を含む: {len(zero2)} 件"
              + (f"（{', '.join(u['unit'] for u in zero2)}）" if zero2 else ""), ""]

    lines += ["## 5. 実際に使われたモデル", "",
              "エイリアスは経路によって別世代へ解決するため（S142）、`--model` にフル ID を渡し、",
              "応答の `system/init` に出た実モデル ID と突き合わせている。**不一致は成功扱いにしない。**", "",
              "| タスク | 指定 | 実測 | 件数 |", "| --- | --- | --- | ---: |"]
    seen = {}
    for r in runs.values():
        key = (r["task_id"], r.get("expect_model"), r.get("actual_model"))
        seen[key] = seen.get(key, 0) + 1
    for (tid, exp, act), n in sorted(seen.items()):
        mark = "" if exp == act else " ← **不一致**"
        lines.append(f"| {tid} | {exp or '—'} | {act or '—'}{mark} | {n} |")
    lines += [""]

    lines += ["## 6. コスト・時間・ツール（成功 run のみ）", "",
              "B の合計には **which-model のプロンプト生成費用を含む**（DESIGN.md §9）。", "",
              "| 腕 | run | 回答$ | 生成$ | 合計$ | 合計時間s | 出力文字 | ツール |",
              "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for arm in ("A", "B"):
        a = agg[arm]
        lines.append(
            f"| {arm} | {a['n']} | {fmt(a['answer_cost'])} | {fmt(a['gen_cost'])} | "
            f"{fmt(a['cost'])} | "
            f"{fmt((a['ms'] or 0) / 1000, 1) if a['ms'] is not None else '—'} | "
            f"{a['chars'] or 0} | {a['tools'] if a['tools'] is not None else '—'} |")
    dc = _diff(agg["B"]["cost"], agg["A"]["cost"])
    dt = _diff(agg["B"]["ms"], agg["A"]["ms"])
    lines += ["",
              f"B − A ： コスト {fmt(dc)} USD ／ 時間 "
              f"{fmt((dt / 1000) if dt is not None else None, 1)} s", "",
              "judge のコスト：",
              f"- Claude（{plan.get('judge_model', '?')}）: "
              f"{fmt(judge_cost['claude'][0])} USD ／ {judge_cost['claude'][1]} 回",
              f"- Codex: {fmt(judge_cost['codex'][0])} USD ／ "
              f"{judge_cost['codex'][1]} 回（サブスクリプション枠。USD が取れない場合は —）", "",
              "> コストは停止規則に入れない（記録・報告のみ）。", ""]

    lines += ["## 7. 人間確認（盲検・不一致分のみ）", "",
              f"- 抽出: {len(need)} 件 → `human-review.md`",
              f"- 確認済み: {sum(1 for u in units if u['human_winner'])} 件", ""]
    if human_errors:
        lines += ["**記法エラー：**", ""] + [f"- {e}" for e in human_errors] + [""]

    lines += ["## 8. 停止規則の評価", "",
              "規則は実行前に凍結してある（`STOP-RULES.md`）。", "",
              "| 規則 | 該当 | 実測 |", "| --- | --- | --- |"]
    for name, hit, detail in rules:
        lines.append(f"| {name} | {'**該当**' if hit else '—'} | {detail} |")
    lines += [""]

    if not complete:
        lines += ["### 判定：**INCOMPLETE / 判定保留**", "",
                  "**完了ゲートを満たしていないため、停止規則を適用しない。**",
                  "上の表は参考値であって、「価値信号なし」ではない。", ""]
        lines += [f"- 未完了: {g}" for g in gaps]
        lines += ["", "同じコマンドを再実行すれば欠けた分だけ埋まる（冪等）。"
                      "**装置の失敗を製品の評価に化けさせないこと。**"]
    elif r4_hit:
        lines += ["### 判定：**判定不能（judge が信頼できない）**", "",
                  "2系統の judge の食い違いが 1/3 を超えた。**この装置の判定を根拠にしない。**",
                  "価値があるとも無いとも言わない。判定装置の設計に戻ること。", ""]
    elif triggered:
        lines += ["### 判定：**価値信号なし**", "",
                  "該当した規則があるため、軸2は「価値信号なし」とする。**B/C 試験へ進まない。**", ""]
        lines += [f"- {name} — {detail}" for name, _, detail in triggered]
    else:
        lines += ["### 判定：**価値信号あり（弱い探索的信号）**", "",
                  "どの停止規則にも該当しない。B/C 試験（モデル固有ガイドの追加価値）へ進んでよい。", "",
                  "**これは「製品価値が実証された」ではない。**"
                  "言えるのは「次の投資に値する」までである（DESIGN.md §10）。"]

    mix = {}
    for t in tasks:
        mix[t["model_id"]] = mix.get(t["model_id"], 0) + 1
    lines += ["", "## 9. 書き方の制約", "",
              "- 「差がなかった」ではなく「この規模では差を検出できなかった」と書く",
              "- 勝敗は率（%）でなく件数で書く",
              f"- タスクが8件に満たない場合はその旨を併記する（今回 {len(tasks)} 件）",
              "- **モデル別の差を結論にしない。** 構成は "
              + "／".join(f"{k} {v}件" for k, v in sorted(mix.items()))
              + " で、モデルごとの比較に耐える数ではない",
              "- 読み取り専用タスクの範囲でしか言えない",
              "- **両 judge が同じ誤りをした場合は検出できない**（DESIGN.md §5 の取引）", ""]

    (AX / "REPORT.md").write_text("\n".join(lines), encoding="utf-8")

    print(f"analyze: tasks={len(tasks)} units={len(units)} runs={len(runs)}")
    print(f"  B勝ち {counts['B']} / A勝ち {counts['A']} / 引き分け {counts['tie']} "
          f"/ 反転 {counts['reversal']} / 保留 {counts['pending']}")
    print(f"  judge 一致: {len(judged) - len(disagree)}/{len(judged)}"
          + (f"（不一致 {len(disagree)} 件 → 人間確認）" if disagree else ""))
    if complete:
        print(f"  停止規則の該当: {len(triggered)} 件"
              + ("（規則4 → 判定不能）" if r4_hit else ""))
    else:
        print("  状態: INCOMPLETE / 判定保留（停止規則を適用していない）")
        for g in gaps:
            print(f"    - {g}")
    print("  → REPORT.md / results.csv / human-review.md / review/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
