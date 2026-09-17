#!/usr/bin/env bash
# blind pairwise 判定：比較単位ごとに左右を入れ替えた2回を判定する（DESIGN.md §7）。
#
# 使い方: bin/grade-pairwise.sh
# 環境変数: CLAUDE_BIN / AXROOT / JUDGE_MODEL
#
# judge には腕ラベル・使用プロンプト・which-model の存在を渡さない。
# 冪等：既にある judgements はスキップする。
# **評価用の呼び出しでは MCP を無効化する**（--strict-mcp-config）。
# --mcp-config を渡さないので、読み込まれる MCP サーバーは 0 個になる。
# 利用者の MCP 設定・接続・認証は変更しない（呼び出し単位のフラグ）。
# 組み込みツール（Read/Grep/Glob）と --plugin-dir の which-model は従来どおり効く。
# 理由：接続済み MCP のツール定義が毎セッション十数万トークン入り、費用と実行条件を歪めるため。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
LIB="$HERE/lib"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

py() { python3 "$LIB/$@"; }
cfgval() { python3 -c "import json,sys;print(json.load(open('$AX/config.json'))['$1'])"; }

echo "== 0) 凍結照合 =="
py freeze.py --check

echo "== 0b) workdir の git 状態（回答時と同じ参照先で判定するため） =="
# judge は context_required のタスクで参照先を読んで実装と照合する。
# 回答の後に参照先が編集されると、回答者が見た実装と judge が見る実装が食い違う。
python3 -c "
import json, sys, pathlib; sys.path.insert(0, '$LIB')
import common, make_plan
plan = json.loads((common.AX / 'plan.json').read_text(encoding='utf-8'))
bad = []
for path, frozen in plan['workdir_state'].items():
    now = make_plan.git_state(pathlib.Path(path))
    if now != frozen:
        bad.append((path, frozen, now))
for path, f, n in bad:
    print(f'ERROR: workdir が凍結時と違う: {path}\n  凍結: {f}\n  現在: {n}', file=sys.stderr)
if bad:
    sys.exit(1)
print('workdir state: ok')
" || {
  if [ "${ALLOW_WORKDIR_DRIFT:-0}" = "1" ]; then
    echo "WARN: ALLOW_WORKDIR_DRIFT=1 のため続行する（判定時の参照先が回答時と異なる）" >&2
  else
    echo "判定を中止する。参照先が回答時と違うと、実装との照合の前提が崩れる。" >&2
    echo "意図した変更なら ALLOW_WORKDIR_DRIFT=1 を付けて実行し、REPORT に記録すること。" >&2
    exit 1
  fi
}

JUDGE_MODEL="${JUDGE_MODEL:-$(cfgval judge_model)}"
JUDGE_EFFORT="$(cfgval judge_effort)"
RETRY_MAX="$(cfgval retry_max)"
OUTFMT="$(cfgval output_format)"
FMT_ARGS=(--output-format "$OUTFMT")
[ "$OUTFMT" = "stream-json" ] && FMT_ARGS+=(--verbose)
SANDBOX="$(python3 -c "import sys; sys.path.insert(0, '$LIB'); import common; print(common.sandbox())")"
[ -d "$SANDBOX" ] || { echo "ERROR: sandbox を決められない" >&2; exit 1; }
mkdir -p "$AX/judgements" "$AX/logs" "$SANDBOX"

# 比較単位ごとの提示順は plan.json で凍結済み（1回目はコイン投げ、2回目はその反転）
python3 -c "
import json, sys; sys.path.insert(0, '$LIB')
import common
plan = json.loads((common.AX / 'plan.json').read_text(encoding='utf-8'))
for unit, orders in sorted(plan['judge_orders'].items()):
    task, rep = unit.rsplit('_r', 1)
    for i, o in enumerate(orders, 1):
        print('\t'.join([task, rep, o, str(i)]))
" > "$AX/logs/_judge_order.tsv"

while IFS=$'\t' read -r ID REP ORDER SEQ; do
  GR="$AX/judgements/${ID}_r${REP}_${SEQ}_${ORDER}.json"
  [ -s "$GR" ] && { echo "skip (exists): ${ID} r${REP} #${SEQ} ${ORDER}"; continue; }
  for ARM in A B; do
    O="$AX/outputs/${ID}_${ARM}_r${REP}.json"
    if [ ! -s "$O" ]; then echo "WARN: 出力が無い（判定を飛ばす）: $O" >&2; continue 2; fi
    ST="$(python3 -c "import json;print(json.load(open('$O'))['status'])")"
    if [ "$ST" != "ok" ]; then echo "WARN: status=${ST}（判定を飛ばす）: $O" >&2; continue 2; fi
  done

  GP="$AX/logs/judge_${ID}_r${REP}_${SEQ}_${ORDER}_prompt.txt"
  py build_judge_prompt.py "$ID" "$REP" "$ORDER" > "$GP"

  # judge の実行条件は回答時と同じにする（DESIGN.md §7）。
  # context_required=true なら同じ workdir と read-only ツールを与え、実装と照合させる。
  # 材料を与えないと judge は文章の説得力・網羅性しか比べられない。
  eval "$(py build_judge_prompt.py --env "$ID")"
  if [ -z "$JUDGE_TOOLS" ]; then JT_ARGS=(--tools ""); else
    # shellcheck disable=SC2206
    JT_ARGS=(--tools $JUDGE_TOOLS); fi
  [ -d "$JUDGE_WORKDIR" ] || { echo "ERROR: judge の workdir が無い: $JUDGE_WORKDIR" >&2; exit 1; }

  ok=0
  for attempt in $(seq 0 "$RETRY_MAX"); do
    GLOG="$AX/logs/judge_${ID}_r${REP}_${SEQ}_${ORDER}_a${attempt}.log"
    (cd "$JUDGE_WORKDIR" && "$CLAUDE_BIN" --model "$JUDGE_MODEL" --effort "$JUDGE_EFFORT" \
      --strict-mcp-config \
      "${JT_ARGS[@]}" "${FMT_ARGS[@]}" -p "$(cat "$GP")" </dev/null) >"$GLOG" 2>&1 || true
    if py parse_judgement.py "$GLOG" "$ID" "$REP" "$ORDER" "$GR" 2>/dev/null && [ -s "$GR" ]; then
      ok=1; break
    fi
    rm -f "$GR"
  done
  if [ "$ok" = 1 ]; then
    V="$(python3 -c "import json;d=json.load(open('$GR'));print(d['verdict'], '->', d['winner_arm'])")"
    echo "judge: ${ID} r${REP} #${SEQ} ${ORDER} : $V"
  else
    echo "WARN: judge_failed: ${ID} r${REP} #${SEQ} ${ORDER}（logs を確認）" >&2
  fi
done < "$AX/logs/_judge_order.tsv"

echo
echo "== 完了ゲート =="
py gate.py judge
echo "判定完了。次は: bin/analyze.sh"
