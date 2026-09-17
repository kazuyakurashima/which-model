#!/usr/bin/env bash
# v2（2026-08-15 実行分）に第2 judge を後付けし、探索的に完了させる（DESIGN.md §6）。
#
# 使い方: bin/retro-v2.sh
#
# **これは凍結後の変更である。** v2 の結果（REPORT.md）を見た後に判定系統を足すので、
# v2 の結論は確認的な試験ではなく**探索的観察**へ格下げする。その旨を v2 の
# STOP-RULES.md §4 へ記録してから実行する。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V3="$(cd "$HERE/.." && pwd)"
V2="$(cd "$V3/../axis2-v2" && pwd)"
CODEX_BIN="${CODEX_BIN:-codex}"

[ -d "$V2" ] || { echo "ERROR: v2 が無い: $V2" >&2; exit 1; }

echo "== 0) v2 の STOP-RULES へ格下げを記録 =="
python3 - "$V2" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "STOP-RULES.md"
s = p.read_text(encoding="utf-8")
line = ("| 2026-09-09 | **第2 judge（Codex）を後付けし、人間確認の代わりに judge 間一致で確定させた** "
        "| v3 の設計変更に合わせて v2 を完了させるため。**結果（REPORT.md）を見た後の変更なので、"
        "v2 の結論は確認的な試験ではなく探索的観察として扱う** |")
if "2026-09-09" in s:
    print("  既に記録済み"); raise SystemExit(0)
marker = "**上の3件はいずれも本実行の前（凍結前）に行った。結果は1件も出ていない。**"
assert s.count(marker) == 1, "変更履歴の位置が見つからない"
s = s.replace(marker, line + "\n\n" + marker)
p.write_text(s, encoding="utf-8")
print("  記録した")
PY

echo "== 1) v3 のコードで v2 のデータを判定する =="
# v2 のディレクトリを AXROOT にし、コードは v3 のものを使う。
# tasks.json に model_id が無いので、判定に必要な範囲だけ補う一時コピーを作る。
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$V2/." "$TMP/ax/" 2>/dev/null || { mkdir -p "$TMP/ax"; cp -R "$V2/." "$TMP/ax/"; }
rm -rf "$TMP/ax/bin"; cp -R "$V3/bin" "$TMP/ax/bin"
mkdir -p "$TMP/ax/judgements2"
python3 - "$TMP/ax" <<'PY'
import json, pathlib, sys
ax = pathlib.Path(sys.argv[1])
p = ax / "tasks.json"
d = json.loads(p.read_text(encoding="utf-8"))
MID = {"fable": "claude-fable-5", "opus": "claude-opus-5", "sonnet": "claude-sonnet-5"}
for t in d["tasks"]:
    t.setdefault("model_id", MID[t["target_model"]])   # v2 実行時の実モデル
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
# 凍結照合を通すため manifest を作り直す（探索的観察であることは §4 に記録済み）
(ax / "manifest.json").unlink(missing_ok=True)
print("tasks.json に model_id を補い、manifest を外した")
PY
export AXROOT="$TMP/ax"
python3 "$V3/bin/lib/freeze.py" --write >/dev/null

echo "== 2) Codex judge（20 回） =="
CODEX_BIN="$CODEX_BIN" "$V3/bin/grade2-codex.sh" || echo "WARN: 判定に欠落あり（再実行で埋まる）" >&2

echo "== 3) 集計 =="
python3 "$V3/bin/lib/analyze.py" || true

echo "== 4) 結果を v2 へ書き戻す（judgements2 と探索的レポート） =="
mkdir -p "$V2/judgements2"
cp -n "$TMP/ax/judgements2/"*.json "$V2/judgements2/" 2>/dev/null || true
for f in REPORT.md human-review.md results.csv; do
  [ -f "$TMP/ax/$f" ] && cp "$TMP/ax/$f" "$V2/${f%.*}-retro-2026-09-09.${f##*.}"
done
cp -R "$TMP/ax/review/." "$V2/review/" 2>/dev/null || true
cat <<EOF

v2 の探索的完了：
  - $V2/judgements2/                     … Codex の判定
  - $V2/REPORT-retro-2026-09-09.md       … v3 のコードで集計した結果（**探索的観察**）
  - $V2/human-review-retro-2026-09-09.md … judge 間で割れた比較（あれば）

**v2 の元の REPORT.md は上書きしていない。**
judge 間一致率は v3 の人間確認量の見積に使う（DESIGN.md §6）。
EOF
