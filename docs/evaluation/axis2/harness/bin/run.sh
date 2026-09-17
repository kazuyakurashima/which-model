#!/usr/bin/env bash
# 回答の実行：manifest 照合 → plan.json の順（ランダム化済み）で A/B を走らせる。
#
# 使い方: bin/run.sh
# 環境変数:
#   CLAUDE_BIN            … claude の実体（既定 claude）
#   AXROOT                … 実験ルート
#   ALLOW_WORKDIR_DRIFT=1 … workdir の git 状態が凍結時と違っても続行する
#
# 冪等：既にある outputs はスキップする。
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

echo "== 0b) workdir の git 状態 =="
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
    echo "WARN: ALLOW_WORKDIR_DRIFT=1 のため続行する（比較条件が凍結時と異なる）" >&2
  else
    echo "実行を中止する。参照先が変わると A/B の比較条件が揃わない。" >&2
    echo "意図した変更なら ALLOW_WORKDIR_DRIFT=1 を付けて実行し、REPORT に記録すること。" >&2
    exit 1
  fi
}

OUTFMT="$(cfgval output_format)"
FMT_ARGS=(--output-format "$OUTFMT")
[ "$OUTFMT" = "stream-json" ] && FMT_ARGS+=(--verbose)
CLAUDE_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | head -1 || echo unknown)"
mkdir -p "$AX/outputs" "$AX/logs"

echo "== 1) 実行（plan.json の run_order。A→B の固定順ではない） =="
python3 -c "
import json, sys; sys.path.insert(0, '$LIB')
import common
plan = json.loads((common.AX / 'plan.json').read_text(encoding='utf-8'))
by = common.task_by_id()
for r in plan['run_order']:
    t = by[r['task']]
    wd = common.resolve_workdir(t)
    tools = ' '.join(t['allowed_tools'])
    print('\t'.join([t['id'], r['arm'], str(r['rep']), t['model_id'],
                     t['target_effort'], str(wd), tools]))
" > "$AX/logs/_run_order.tsv"

# RUN_LIMIT：**新規に実行する run の上限**（未設定なら無制限）。
# plan.json の run_order は seed で固定済みなので、**どれを・どの順で走らせるかは変わらない。**
# 区切って費用を確認するための一時停止であって、対象や採点基準には影響しない。
N=0
RUN_DONE=0
# TMODEL は tasks.json の model_id（フル ID）。エイリアスは使わない（S142）。
while IFS=$'\t' read -r ID ARM REP TMODEL TEFFORT WORKDIR TOOLS; do
  N=$((N + 1))
  OUT="$AX/outputs/${ID}_${ARM}_r${REP}.json"
  [ -s "$OUT" ] && { echo "skip (exists): ${ID}_${ARM}_r${REP}"; continue; }
  if [ -n "${RUN_LIMIT:-}" ] && [ "$RUN_DONE" -ge "${RUN_LIMIT}" ]; then
    echo "RUN_LIMIT=${RUN_LIMIT} に達した。ここで止める（同じコマンドで続きから再開できる）"
    break
  fi
  RUN_DONE=$((RUN_DONE + 1))
  if [ "$ARM" = "A" ]; then P="$AX/prompts/A/${ID}.txt"; else P="$AX/prompts/B/${ID}_r${REP}.txt"; fi
  [ -s "$P" ] || { echo "WARN: prompt missing: $P — skip" >&2; continue; }
  [ -d "$WORKDIR" ] || { echo "ERROR: workdir が無い: $WORKDIR" >&2; exit 1; }

  # ツールはタスク単位。空文字なら完全無効（--tools ""）
  if [ -z "$TOOLS" ]; then TOOL_ARGS=(--tools ""); else
    # shellcheck disable=SC2206
    TOOL_ARGS=(--tools $TOOLS); fi

  RAWOUT="$AX/logs/run_${ID}_${ARM}_r${REP}.log"
  T0=$(date +%s)
  set +e
  (cd "$WORKDIR" && "$CLAUDE_BIN" --model "$TMODEL" --effort "$TEFFORT" \
     --strict-mcp-config \
     "${TOOL_ARGS[@]}" "${FMT_ARGS[@]}" -p "$(cat "$P")" </dev/null) \
     >"$RAWOUT" 2>"$AX/logs/run_${ID}_${ARM}_r${REP}.err"
  RC=$?
  set -e
  T1=$(date +%s)
  py record_run.py "$RAWOUT" "$OUT" \
    --task "$ID" --arm "$ARM" --rep "$REP" --model "$TMODEL" --effort "$TEFFORT" \
    --prompt-file "$P" --workdir "$WORKDIR" --tools "$TOOLS" \
    --claude-version "$CLAUDE_VERSION" --elapsed "$((T1 - T0))" --rc "$RC" \
    --expect-model "$TMODEL" \
    || echo "WARN: run failed: ${ID}_${ARM}_r${REP}（logs を確認）" >&2
  echo "run[$N]: ${ID}_${ARM}_r${REP} rc=$RC $((T1 - T0))s"
done < "$AX/logs/_run_order.tsv"

echo
echo "== 2) 完了ゲート =="
py gate.py run
echo "実行完了。次は: bin/grade-pairwise.sh"
