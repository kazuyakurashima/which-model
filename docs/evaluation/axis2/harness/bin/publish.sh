#!/usr/bin/env bash
# 公開物を docs/evaluation/axis2/ へ生成する（DESIGN.md §8）。
#
# 使い方: bin/publish.sh
#
# **許可リストにあるものだけを出す。** 依頼文・回答本文・判定理由は公開しない
# （私有リポジトリの構造や設計判断が漏れるため）。生成後に私有パス・プロジェクト名を
# grep し、ヒットしたら非ゼロ終了する。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
REPO="${WM_REPO:-$(cd "$AX/../.." && pwd)}"
DST="$REPO/docs/evaluation/axis2"

[ -s "$AX/REPORT.md" ] || { echo "ERROR: REPORT.md が無い。先に analyze.sh を実行すること" >&2; exit 1; }
if ! grep -q "^\*\*状態：完了\*\*" "$AX/REPORT.md"; then
  echo "ERROR: REPORT.md が完了状態でない。人間確認を投入して analyze.sh を再実行すること" >&2
  exit 1
fi

mkdir -p "$DST/harness/bin/lib" "$DST/harness/tests"

echo "== 1) 報告書・設計・停止規則 =="
cp "$AX/REPORT.md" "$DST/REPORT.md"
cp "$AX/DESIGN.md" "$DST/DESIGN.md"
cp "$AX/STOP-RULES.md" "$DST/STOP-RULES.md"
[ -f "$AX/probe.json" ] && cp "$AX/probe.json" "$DST/probe.json"

echo "== 2) ハーネス一式（コード・設定・配管テスト） =="
cp "$AX/bin/"*.sh "$DST/harness/bin/"
cp "$AX/bin/lib/"*.py "$AX/bin/lib/"*.txt "$AX/bin/lib/"*.json "$DST/harness/bin/lib/"
cp "$AX/tests/fake-claude.py" "$AX/tests/fake-codex.py" "$DST/harness/tests/"
cp "$AX/config.json" "$DST/harness/config.json"
cp "$AX/manifest.json" "$DST/harness/manifest.json"

echo "== 3) タスクの公開版（依頼文は t06 だけ） =="
python3 - "$AX" "$DST" <<'PY'
import hashlib, json, pathlib, sys
ax, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
d = json.loads((ax / "tasks.json").read_text(encoding="utf-8"))
out = {"_note": ("軸2 v3 の実課題の公開版。**依頼文は原則載せない**"
                 "（私有リポジトリの構造・設計判断が漏れるため）。"
                 "リポジトリを参照しない t06 だけ全文を載せる。"
                 "同一性は text_sha256 で確認できる。"),
       "tasks": []}
for t in d["tasks"]:
    row = {"id": t["id"], "kind": t.get("_kind"),
           "model_id": t["model_id"], "target_effort": t["target_effort"],
           "context_required": t["context_required"],
           "text_chars": len(t["text"]),
           "text_sha256": hashlib.sha256(t["text"].encode()).hexdigest()}
    if t["id"] == "t06_post_strategy_review":
        row["text"] = t["text"]
    out["tasks"].append(row)
(dst / "tasks.public.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n",
                                       encoding="utf-8")
print(f"  tasks.public.json（{len(out['tasks'])} 件・全文は t06 のみ）")
PY

echo "== 4) 判定の公開版（理由・引用は落とす） =="
python3 - "$AX" "$DST" <<'PY'
import csv, glob, json, pathlib, sys
ax, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
rows = []
for sub, fam in (("judgements", "claude"), ("judgements2", "codex")):
    for p in sorted((ax / sub).glob("*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        rows.append({"unit": f"{d['task_id']}_r{d['rep']}", "task": d["task_id"],
                     "rep": d["rep"], "order": d["order"],
                     "judge_family": d.get("judge_family", fam),
                     "judge_model": d.get("judge_model", ""),
                     "verdict": d["verdict"], "winner_arm": d["winner_arm"],
                     "critical_error_arm": d.get("critical_error_arm") or "",
                     "tool_calls": d.get("judge_tool_calls")})
cols = ["unit", "task", "rep", "order", "judge_family", "judge_model",
        "verdict", "winner_arm", "critical_error_arm", "tool_calls"]
with (dst / "judgements.public.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
    w.writeheader()
    for r in sorted(rows, key=lambda x: (x["unit"], x["judge_family"], x["order"])):
        w.writerow(r)
print(f"  judgements.public.csv（{len(rows)} 行・reason/evidence は落とした）")

# run の公開版（回答本文は落とし、実測値だけ）
runs = []
for p in sorted((ax / "outputs").glob("*.json")):
    d = json.loads(p.read_text(encoding="utf-8"))
    runs.append({k: d.get(k) for k in
                 ("task_id", "arm", "rep", "expect_model", "actual_model", "effort",
                  "status", "output_chars", "tool_calls", "answer_cost_usd",
                  "gen_cost_usd", "total_cost_usd", "total_duration_ms")})
with (dst / "runs.public.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(runs[0].keys()))
    w.writeheader()
    for r in runs:
        w.writerow(r)
print(f"  runs.public.csv（{len(runs)} 行・result 本文は落とした）")
PY

echo "== 5) 私有情報の流出検査 =="
python3 - "$DST" <<'PY'
import pathlib, re, sys
dst = pathlib.Path(sys.argv[1])
# 私有パス・プロジェクト名。公開物に出てはいけない。
BAD = [r"/Users/[A-Za-z0-9._-]+", r"<private-repo-1>", r"<private-repo-2>",
       r"<private-dir-2>", r"<private-dir-1>", r"<private-dir-3>"]
hits = []
for p in sorted(dst.rglob("*")):
    if not p.is_file():
        continue
    try:
        s = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    for pat in BAD:
        for m in re.finditer(pat, s):
            hits.append((p.relative_to(dst), pat, s[max(0, m.start() - 30):m.end() + 30]
                         .replace("\n", " ")))
if hits:
    print(f"ERROR: 公開物に私有情報が {len(hits)} 件残っている", file=sys.stderr)
    for rel, pat, ctx in hits[:25]:
        print(f"  - {rel} … /{pat}/ … …{ctx}…", file=sys.stderr)
    if len(hits) > 25:
        print(f"  … 他 {len(hits) - 25} 件", file=sys.stderr)
    print("\n**公開しない。** 該当箇所を落としてから publish.sh を再実行すること。",
          file=sys.stderr)
    sys.exit(1)
print("  流出検査: ok")
PY

cat <<EOF

公開物を生成した: $DST
  REPORT.md / DESIGN.md / STOP-RULES.md / probe.json
  tasks.public.json / judgements.public.csv / runs.public.csv
  harness/（bin・tests・config・manifest）

次にやること:
  1. README に「価値検証」の節を足し、結論を STOP-RULES.md §3 の書き方でそのまま書く
     （**否定的なら否定的と書く**）
  2. git add docs/evaluation/axis2 && コミット
EOF
