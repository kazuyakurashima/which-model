#!/usr/bin/env bash
# 人間確認を行わずに閉じた v3 の公開物を docs/evaluation/axis2/ へ生成する。
#
# 使い方: checks/publish_closing.sh
#
# bin/publish.sh は REPORT.md が「状態：完了」でないと止まり、凍結対象なので書き換えられない。
# その代わりに使う。**許可リストは bin/publish.sh と同じ。** 変更点は CLOSING-2026-09-17.md §8：
#   - 完了状態の確認の代わりに、終了記録（CLOSING）があることを確認し、それも公開する
#   - 公開前に凍結87ファイルを manifest.json と照合する
#   - REPORT.md の公開版の冒頭に、未完了の集計であることの注記を足す（本文は変えない）
#   - t06 の依頼文も載せない
#   - 公開コピーだけ、私有リポジトリ名とローカルのパスを伏せ字にする
#     （公開コピーでは、下の置換表と検査語の一覧も伏せ字になる）
#
# 一時ディレクトリで作り、伏せ字と流出検査に合格したときだけ DST へ移す。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
REPO="${WM_REPO:-$(cd "$AX/../.." && pwd)}"
DST="$REPO/docs/evaluation/axis2"
CLOSING="CLOSING-2026-09-17.md"

[ -s "$AX/REPORT.md" ] || { echo "ERROR: REPORT.md が無い" >&2; exit 1; }
[ -s "$AX/$CLOSING" ] || { echo "ERROR: $CLOSING が無い。終了記録を先に書くこと" >&2; exit 1; }

echo "== 0) 凍結の照合 =="
python3 "$AX/bin/lib/freeze.py" --check

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/axis2"
mkdir -p "$OUT/harness/bin/lib" "$OUT/harness/tests" "$OUT/harness/checks"

echo "== 1) 終了記録・報告書・設計・停止規則 =="
cp "$AX/$CLOSING" "$OUT/$CLOSING"
python3 - "$AX/REPORT.md" "$OUT/REPORT.md" "$CLOSING" <<'PY'
import pathlib, sys
src, dst, closing = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
lines = src.read_text(encoding="utf-8").split("\n")
if not lines[0].startswith("# "):
    sys.exit("ERROR: REPORT.md の1行目が見出しでない")
note = [
    "",
    "> **公開版の注記（2026-09-17）**",
    "> これは**未完了の機械集計**である（状態：INCOMPLETE）。判定者の意見が割れた組の人間確認を行わずに実験を閉じたため、",
    "> 下の勝敗や停止規則の「該当」は結論ではない。終了の判断・理由・限界は",
    f"> [{closing}]({closing}) を参照すること。",
    "> 盲検が崩れうる2組の扱いと、§6 の「Claude（?）」の実際のモデルもそこに書いてある。",
    "> この注記より下は、集計コード（`bin/lib/analyze.py`）の出力のまま変えていない。",
]
dst.write_text("\n".join(lines[:1] + note + lines[1:]), encoding="utf-8")
print("  REPORT.md（冒頭に注記を追加）")
PY
cp "$AX/DESIGN.md" "$OUT/DESIGN.md"
cp "$AX/STOP-RULES.md" "$OUT/STOP-RULES.md"
[ -f "$AX/probe.json" ] && cp "$AX/probe.json" "$OUT/probe.json"

echo "== 2) ハーネス一式（コード・設定・配管テスト） =="
cp "$AX/bin/"*.sh "$OUT/harness/bin/"
cp "$AX/bin/lib/"*.py "$AX/bin/lib/"*.txt "$AX/bin/lib/"*.json "$OUT/harness/bin/lib/"
cp "$AX/tests/fake-claude.py" "$AX/tests/fake-codex.py" "$OUT/harness/tests/"
cp "$AX/config.json" "$OUT/harness/config.json"
cp "$AX/manifest.json" "$OUT/harness/manifest.json"
cp "$HERE/publish_closing.sh" "$OUT/harness/checks/publish_closing.sh"

echo "== 3) タスクの公開版（依頼文は載せない） =="
python3 - "$AX" "$OUT" <<'PY'
import hashlib, json, pathlib, sys
ax, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
d = json.loads((ax / "tasks.json").read_text(encoding="utf-8"))
out = {"_note": ("軸2 v3 の実課題の公開版。**依頼文は載せない**"
                 "（私有リポジトリの構造・設計判断が漏れるため。"
                 "設計時は t06 だけ全文を載せる予定だったが、2026-09-17 の作者の決定で載せないことにした）。"
                 "同一性は text_sha256 で確認できる。"),
       "tasks": []}
for t in d["tasks"]:
    out["tasks"].append({"id": t["id"], "kind": t.get("_kind"),
                         "model_id": t["model_id"], "target_effort": t["target_effort"],
                         "context_required": t["context_required"],
                         "text_chars": len(t["text"]),
                         "text_sha256": hashlib.sha256(t["text"].encode()).hexdigest()})
(dst / "tasks.public.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n",
                                       encoding="utf-8")
print(f"  tasks.public.json（{len(out['tasks'])} 件・依頼文なし）")
PY

echo "== 4) 判定と run の公開版（理由・引用・回答本文は落とす） =="
python3 - "$AX" "$OUT" <<'PY'
import csv, json, pathlib, sys
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

echo "== 5) 伏せ字（公開コピーだけ）と manifest との照合 =="
python3 - "$AX" "$OUT" <<'PY'
import hashlib, json, pathlib, re, sys
ax, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
# ローカルの絶対パスは、ユーザー名の後ろに続くパスごと置き換える。
PATH_RE = re.compile(r"/Users/[A-Za-z0-9._-]+/[^\s\"'`)\]|,]*")
# 長い語から置き換える（部分一致で半端に残さないため）。
TERMS = [("<private-repo-2>", "<private-repo-2>"),
         ("<private-repo-2>", "<private-repo-2>"),
         ("<private-repo-1>", "<private-repo-1>"),
         # 下の流出検査は語の一部でも拾う。このスクリプト自身の公開コピーが引っかからないように揃える。
         ("<private-repo-2>", "<private-repo-2>"),
         ("<private-repo-2>", "<private-repo-2>"),
         ("<private-repo-1>", "<private-repo-1>"),
         ("<private-dir-1>", "<private-dir-1>"),
         ("<private-dir-2>", "<private-dir-2>"),
         ("<private-dir-3>", "<private-dir-3>")]
redacted = {}
for p in sorted(dst.rglob("*")):
    if not p.is_file():
        continue
    try:
        s = p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    t, n = PATH_RE.subn("<local-path>", s)
    for old, new in TERMS:
        n += t.count(old)
        t = t.replace(old, new)
    if n:
        p.write_text(t, encoding="utf-8")
        redacted[str(p.relative_to(dst))] = n
for rel, n in redacted.items():
    print(f"  伏せ字: {rel}（{n} 箇所）")

# 公開コピーと凍結時のハッシュを突き合わせる。一致しないのは伏せ字をかけたものだけのはず。
frozen = json.loads((ax / "manifest.json").read_text(encoding="utf-8"))["freezes"][-1]["hashes"]
def frozen_key(rel):
    if rel in ("DESIGN.md", "STOP-RULES.md"):
        return rel
    if rel.startswith("harness/"):
        k = rel[len("harness/"):]
        return k if k in frozen else None
    return None
mismatch, checked = [], 0
for p in sorted(dst.rglob("*")):
    rel = str(p.relative_to(dst))
    k = frozen_key(rel) if p.is_file() else None
    if k is None:
        continue
    checked += 1
    if hashlib.sha256(p.read_bytes()).hexdigest() != frozen[k]:
        mismatch.append(rel)
unexpected = [r for r in mismatch if r not in redacted]
if unexpected:
    sys.exit(f"ERROR: 伏せ字をかけていないのに凍結時と違う公開コピーがある: {unexpected}")
print(f"  manifest と照合: {checked} 件中 {len(mismatch)} 件が不一致（すべて伏せ字によるもの）: {mismatch}")
PY

echo "== 6) 私有情報の流出検査 =="
python3 - "$OUT" <<'PY'
import pathlib, re, sys
dst = pathlib.Path(sys.argv[1])
# 私有パス・プロジェクト名。公開物に出てはいけない。
BAD = [r"/Users/[A-Za-z0-9._-]+", r"<private-repo-1>", r"<private-repo-2>", r"<private-repo-2>",
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
    print("\n**公開しない。**", file=sys.stderr)
    sys.exit(1)
print("  流出検査: ok")
PY

rm -rf "$DST"
mkdir -p "$(dirname "$DST")"
mv "$OUT" "$DST"

cat <<EOF

公開物を生成した: $DST
  $CLOSING / REPORT.md / DESIGN.md / STOP-RULES.md / probe.json
  tasks.public.json / judgements.public.csv / runs.public.csv
  harness/（bin・tests・checks・config・manifest）
EOF
