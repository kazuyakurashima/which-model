#!/usr/bin/env python3
"""計上できた費用の合計と、取得できない費用の一覧（DESIGN.md §9）。

使い方: sum_cost.py <axroot> --total     … 合計（USD）を1行で
        sum_cost.py <axroot> --unknown   … 取得できない費用の説明を1行で
        sum_cost.py <axroot> --detail    … 内訳を人間向けに

**これは「使った額」ではなく「取得できた分の合計」である。**
取得できない費用（Codex 判定など）はゼロとして足し込まず、`--unknown` に出す。

二重計上を避ける規則：
- `outputs/*.json` の `total_cost_usd` は「回答＋その反復の B 生成」の合算である。
  したがって `gen/*.json` を無条件に足すと **B 生成費を二重に数える**。
  gen は「対応する回答 run がまだ無いもの」だけを足す。
"""
import argparse
import glob
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parse_stream  # noqa: E402


def log_cost(path: pathlib.Path):
    if not path.is_file():
        return None
    d = parse_stream.parse(path.read_text(encoding="utf-8", errors="replace"))
    v = d.get("cost_usd")
    return v if isinstance(v, (int, float)) else None


def breakdown(ax: str):
    axp = pathlib.Path(ax)
    parts = {}

    # 1) 回答 run（B は総額に生成費を含む）
    answers = 0.0
    counted_gen = set()
    for p in glob.glob(f"{ax}/outputs/*.json"):
        d = json.load(open(p))
        v = d.get("total_cost_usd")
        if isinstance(v, (int, float)):
            answers += v
            if d.get("arm") == "B" and d.get("gen_cost_usd") is not None:
                counted_gen.add(f"{d['task_id']}_r{d['rep']}")
    parts["回答 run（B は生成費込み）"] = answers

    # 2) まだ回答 run が無い B 生成（生成だけ済んだ段階でも計上する）
    gen_only = 0.0
    for p in glob.glob(f"{ax}/gen/*.json"):
        if pathlib.Path(p).stem in counted_gen:
            continue                      # 回答 run 側で計上済み → 二重計上しない
        v = json.load(open(p)).get("gen_cost_usd")
        if isinstance(v, (int, float)):
            gen_only += v
    parts["B 生成のみ（回答前）"] = gen_only

    # 2b) **孤立した B 生成の試行**（gen/*.json が無いログ）。
    #     中断などで record_gen まで届かなかった試行は、費用だけ発生して記録に残らない。
    #     ログがあるものは拾う（2026-09-14 に実際に 1 試行漏れた）。
    recorded_keys = {pathlib.Path(p).stem for p in glob.glob(f"{ax}/gen/*.json")}
    orphan = 0.0
    n_orphan = 0
    for p in sorted(glob.glob(f"{ax}/logs/gen_*phase*.log")):
        key = pathlib.Path(p).stem.replace("gen_", "", 1).rsplit("_a", 1)[0]
        if key in recorded_keys:
            continue                    # record_gen が全 leg を合算済み
        v = log_cost(pathlib.Path(p))
        if v is not None:
            orphan += v
            n_orphan += 1
    parts[f"中断した B 生成の試行（{n_orphan} 実行）"] = orphan

    # 2c) **退避した試行**（archive/*/cost.json）。作り直しのために生成物を退避すると
    #     logs/ と gen/ から消えるので、退避前に実測した費用をここで数え続ける。
    arch = 0.0
    n_arch = 0
    for p in sorted(glob.glob(f"{ax}/archive/*/cost.json")):
        try:
            v = json.loads(pathlib.Path(p).read_text(encoding="utf-8")).get("usd")
        except (OSError, json.JSONDecodeError):
            v = None
        if isinstance(v, (int, float)):
            arch += v
            n_arch += 1
    parts[f"退避した試行（{n_arch} 件・作り直し前）"] = arch

    # 3) Claude judge（採用された判定）
    j1 = 0.0
    for p in glob.glob(f"{ax}/judgements/*.json"):
        v = json.load(open(p)).get("judge_cost_usd")
        if isinstance(v, (int, float)):
            j1 += v
    parts["Claude judge（採用分）"] = j1

    # 4) 採用されなかった judge のリトライ分。
    #    どの attempt が採用されたかは記録に無いので、**最後の attempt を採用分とみなす**近似。
    retries = 0.0
    n_retry = 0
    groups = {}
    for p in glob.glob(f"{ax}/logs/judge_*_a*.log"):
        stem = pathlib.Path(p).stem
        base = stem.rsplit("_a", 1)[0]
        groups.setdefault(base, []).append(p)
    for base, paths in groups.items():
        paths = sorted(paths)
        adopted = axp / "judgements" / (base.replace("judge_", "", 1) + ".json")
        drop_last = adopted.is_file()
        for p in (paths[:-1] if drop_last else paths):
            v = log_cost(pathlib.Path(p))
            if v is not None:
                retries += v
                n_retry += 1
    parts[f"judge のリトライ分（{n_retry} 実行）"] = retries

    # 5) プローブ（Claude 側）。**全試行ぶんを足す。**
    #    ログは試行ごとに時刻つきで残る（上書きしない）ので、再実行分も拾える。
    probe = 0.0
    n_probe = 0
    for p in sorted(glob.glob(f"{ax}/logs/probe_fable51*.log")):
        v = log_cost(pathlib.Path(p))
        if v is not None:
            probe += v
            n_probe += 1
    parts[f"プローブ Claude（{n_probe} 試行）"] = probe

    return parts


def _codex_cost_known(log_path: str) -> bool:
    """その Codex 試行の USD が取得できているか（取得できれば費用不明に数えない）。"""
    try:
        sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
        import judge2_codex as jc
        _, cost = jc.usage_of(jc.read_events(log_path))
        return cost is not None
    except Exception:
        return False


def lost(ax: str):
    """記録が失われた試行の推定。**確認できる記録とは分けて出す。**"""
    p = pathlib.Path(ax) / "probe.json"
    if not p.is_file():
        return []
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return d.get("lost_attempts") or []


def unknown(ax: str):
    items = []
    n = len(glob.glob(f"{ax}/judgements2/*.json"))
    nocost = sum(1 for p in glob.glob(f"{ax}/judgements2/*.json")
                 if json.load(open(p)).get("judge_cost_usd") is None)
    if n:
        items.append(f"Codex judge {nocost}/{n} 件（USD を取得できない）")
    pr = pathlib.Path(ax) / "probe.json"
    if pr.is_file():
        try:
            d = json.loads(pr.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            d = {}
        # **ディスク上のログを数える。** history への付け漏れで過少計上しないため
        # （実際に 1 件漏れて 2 回と表示した。2026-09-10）。
        n_hist = sum(1 for lp in glob.glob(f"{ax}/logs/probe_codex_*.jsonl")
                     if not _codex_cost_known(lp))
        # 記録が失われた Codex 試行も「費用不明」に含める。
        # **金額が推定できているものは lost の推定側で数えるので、ここには入れない**
        # （二重計上を避ける）。
        n_lost = sum(1 for x in (d.get("lost_attempts") or [])
                     if "Codex" in (x.get("what") or "") and x.get("estimated_usd") is None)
        n = n_hist + n_lost
        if n:
            detail = []
            if n_hist:
                detail.append(f"記録あり {n_hist}")
            if n_lost:
                detail.append(f"記録が失われた分 {n_lost}")
            items.append(f"プローブの Codex {n} 試行（USD を取得できない／"
                         + "・".join(detail) + "）")
    return items or ["なし"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("axroot")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--total", action="store_true")
    g.add_argument("--unknown", action="store_true")
    g.add_argument("--detail", action="store_true")
    a = ap.parse_args()

    if a.unknown:
        print(" ／ ".join(unknown(a.axroot)))
        return 0
    parts = breakdown(a.axroot)
    total = sum(parts.values())
    if a.total:
        print(f"{total:.2f}")
        return 0
    print("計上できた費用（API 換算・取得できた分だけ）")
    for k, v in parts.items():
        print(f"  {k:32s} ${v:8.3f}")
    print(f"  {'合計（確認できる記録）':32s} ${total:8.3f}")
    ls = lost(a.axroot)
    if ls:
        est = sum(x.get("estimated_usd") or 0 for x in ls)
        print(f"\n記録が失われた試行の**推定**（確認できる記録ではない）: ${est:.3f}")
        for x in ls:
            e = x.get("estimated_usd")
            print(f"  - {x.get('what')}: "
                  + (f"約 ${e:.3f}" if e else "金額不明")
                  + f"（{x.get('basis')}）")
    print("\n取得できない費用（ゼロ扱いしない）")
    for u in unknown(a.axroot):
        print(f"  - {u}")
    print("\n**この合計は総額の保証ではない。** 段の切れ目でしか確認しないので、"
          "段の内側では目安を超えうる。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
