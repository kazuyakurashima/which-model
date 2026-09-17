#!/usr/bin/env bash
# 第2 judge（Codex）による blind pairwise 判定（DESIGN.md §3）。
#
# 使い方: bin/grade2-codex.sh
# 環境変数: CODEX_BIN / AXROOT / JUDGE2_MODEL
#
# Claude 側（bin/grade-pairwise.sh）と独立に走る。提示順は plan.json の judge_orders と同じ。
# judge には腕ラベル・使用プロンプト・which-model の存在を渡さない。
# 冪等：既にある judgements2 はスキップする。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
LIB="$HERE/lib"
CODEX_BIN="${CODEX_BIN:-codex}"

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

JUDGE2_MODEL="${JUDGE2_MODEL:-$(cfgval judge2_model)}"
JUDGE2_EFFORT="$(cfgval judge2_effort)"
RETRY_MAX="$(cfgval retry_max)"
SANDBOX="$(python3 -c "import sys; sys.path.insert(0, '$LIB'); import common; print(common.sandbox())")"
[ -d "$SANDBOX" ] || { echo "ERROR: sandbox を決められない" >&2; exit 1; }
mkdir -p "$AX/judgements2" "$AX/logs" "$SANDBOX"

python3 -c "
import json, sys; sys.path.insert(0, '$LIB')
import common
plan = json.loads((common.AX / 'plan.json').read_text(encoding='utf-8'))
for unit, orders in sorted(plan['judge_orders'].items()):
    task, rep = unit.rsplit('_r', 1)
    for i, o in enumerate(orders, 1):
        print('\t'.join([task, rep, o, str(i)]))
" > "$AX/logs/_judge2_order.tsv"

while IFS=$'\t' read -r ID REP ORDER SEQ; do
  GR="$AX/judgements2/${ID}_r${REP}_${SEQ}_${ORDER}.json"
  [ -s "$GR" ] && { echo "skip (exists): ${ID} r${REP} #${SEQ} ${ORDER}"; continue; }
  for ARM in A B; do
    O="$AX/outputs/${ID}_${ARM}_r${REP}.json"
    if [ ! -s "$O" ]; then echo "WARN: 出力が無い（判定を飛ばす）: $O" >&2; continue 2; fi
    ST="$(python3 -c "import json;print(json.load(open('$O'))['status'])")"
    if [ "$ST" != "ok" ]; then echo "WARN: status=${ST}（判定を飛ばす）: $O" >&2; continue 2; fi
  done

  GP="$AX/logs/judge2_${ID}_r${REP}_${SEQ}_${ORDER}_prompt.txt"
  py build_judge_prompt.py "$ID" "$REP" "$ORDER" codex > "$GP"
  eval "$(py build_judge_prompt.py --env "$ID")"
  [ -d "$JUDGE_WORKDIR" ] || { echo "ERROR: judge の workdir が無い: $JUDGE_WORKDIR" >&2; exit 1; }

  ok=0
  for attempt in $(seq 0 "$RETRY_MAX"); do
    GLOG="$AX/logs/judge2_${ID}_r${REP}_${SEQ}_${ORDER}_a${attempt}.jsonl"
    GLAST="$AX/logs/judge2_${ID}_r${REP}_${SEQ}_${ORDER}_a${attempt}.last.txt"
    # --ignore-user-config：利用者の config.toml は notify で外部アプリを起動するため無効化する
    #                       （認証は CODEX_HOME から読まれる）
    # --sandbox read-only ：判定は読むだけ。書き込みを許さない
    # --ephemeral         ：セッションを残さない
    # --output-schema     ：verdict を 5 値に固定する
    # **古い last-message を先に消す。** 残っていると、失敗した実行でも前回の判定を
    # 今回の成功結果として拾ってしまう。
    rm -f "$GLAST"
    set +e
    "$CODEX_BIN" exec \
      --ignore-user-config \
      -m "$JUDGE2_MODEL" \
      -c "model_reasoning_effort=\"$JUDGE2_EFFORT\"" \
      --sandbox read-only \
      -C "$JUDGE_WORKDIR" \
      --skip-git-repo-check \
      --ephemeral \
      --json \
      --color never \
      -o "$GLAST" \
      --output-schema "$LIB/judge_schema.json" \
      "$(cat "$GP")" </dev/null >"$GLOG" 2>"${GLOG%.jsonl}.err"
    CRC=$?
    set -e
    # 終了コードと正常完了イベントを judge2_codex.py が確認する。
    # **判定 JSON が取れたことだけを成功の根拠にしない。**
    if py judge2_codex.py "$GLOG" "$GLAST" "$ID" "$REP" "$ORDER" "$GR" --rc "$CRC" \
       && [ -s "$GR" ]; then
      ok=1; break
    fi
    rm -f "$GR"
  done
  if [ "$ok" = 1 ]; then
    V="$(python3 -c "import json;d=json.load(open('$GR'));print(d['verdict'],'->',d['winner_arm'],'tools=',d['judge_tool_calls'])")"
    echo "judge2: ${ID} r${REP} #${SEQ} ${ORDER} : $V"
  else
    echo "WARN: judge2_failed: ${ID} r${REP} #${SEQ} ${ORDER}（logs を確認）" >&2
  fi
done < "$AX/logs/_judge2_order.tsv"

echo
echo "== 完了ゲート =="
py gate.py judge2
echo "第2 judge 完了。次は: bin/analyze.sh"
