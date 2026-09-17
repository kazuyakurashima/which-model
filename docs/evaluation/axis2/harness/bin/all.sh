#!/usr/bin/env bash
# 人間確認の直前まで一括で進める（DESIGN.md §7）。冪等・再開可能。
#
# 使い方:
#   bin/all.sh            # 段 0（無料）だけ実行して止まる
#   bin/all.sh --paid     # 有料段まで通す（**課金される**）
#
# 環境変数: MAX_USD（既定 120）… **段の切れ目で見る目安**。総額を保証する上限ではない。
#           1 段の内側では止まらないので、段の途中で目安を超えることはありうる。
#           Codex の費用は USD を取得できないため、この数字には入らない（別に「不明」と出す）。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
LIB="$HERE/lib"
MAX_USD="${MAX_USD:-120}"
PAID=0
[ "${1:-}" = "--paid" ] && PAID=1
mkdir -p "$AX/logs"
LOG="$AX/logs/all.log"

say() { echo -e "\n########## $* ##########" | tee -a "$LOG"; }
run() { echo "\$ $*" | tee -a "$LOG"; "$@" 2>&1 | tee -a "$LOG"; }

# 計上できた費用の合計（API 換算）。
# **「使った額」ではなく「取得できた分の合計」である。** 取れないものはゼロとして
# 足し込まず、unknown_costs に出す。
spent() {
  python3 "$LIB/sum_cost.py" "$AX" --total
}

# 取得できなかった費用（ゼロ扱いしない）
unknown_costs() {
  python3 "$LIB/sum_cost.py" "$AX" --unknown
}

# **段の切れ目で見るだけの確認。総額を保証する上限ではない。**
# 1 段の内側では止まらないので、段の途中で目安を超えることはありうる。
guard() {
  s="$(spent)"
  u="$(unknown_costs)"
  echo "計上できた累計（API 換算）: \$${s} ／ 目安 \$${MAX_USD}" | tee -a "$LOG"
  echo "取得できない費用: ${u}" | tee -a "$LOG"
  python3 -c "import sys; sys.exit(0 if float('$s') <= float('$MAX_USD') else 1)" || {
    echo "目安を超えた。**段の切れ目で停止する**（総額の保証ではない）。" | tee -a "$LOG" >&2
    echo "設計の §9 に従い、利用者へ報告すること。" | tee -a "$LOG" >&2
    exit 2
  }
}

say "段 0：配管テスト（無料・モデルを呼ばない）"
run "$HERE/selftest.sh"

if [ "$PAID" != 1 ]; then
  cat <<EOF | tee -a "$LOG"

段 0 まで完了。ここから先は課金される。
続けるには --paid を付けて実行すること:
  bin/all.sh --paid
EOF
  exit 0
fi

say "段 1：プローブ（Fable 5.1 の疎通 ／ Codex のイベント形）"
run "$HERE/probe-models.sh"; guard

say "段 2：準備（タスク検証 → plan → A/B プロンプト → B の確定モデル検査 → 凍結）"
run "$HERE/prepare.sh"; guard

say "段 3：回答の実行（40 run・ランダム順）"
run "$HERE/run.sh"; guard

say "段 4/5：判定（Claude と Codex を並行）"
"$HERE/grade-pairwise.sh" >>"$AX/logs/judge_claude.log" 2>&1 &
P1=$!
"$HERE/grade2-codex.sh" >>"$AX/logs/judge_codex.log" 2>&1 &
P2=$!
echo "Claude judge pid=$P1 / Codex judge pid=$P2（進行は logs/judge_*.log）" | tee -a "$LOG"
FAILED=0
wait $P1 || { echo "WARN: Claude judge が非ゼロ終了（完了ゲート未達の可能性）" | tee -a "$LOG" >&2; FAILED=1; }
wait $P2 || { echo "WARN: Codex judge が非ゼロ終了（完了ゲート未達の可能性）" | tee -a "$LOG" >&2; FAILED=1; }
tail -5 "$AX/logs/judge_claude.log" "$AX/logs/judge_codex.log" | tee -a "$LOG"
guard

say "段 6：集計"
run "$HERE/analyze.sh" || true

cat <<EOF | tee -a "$LOG"

########## ここで人間の手が要る ##########

judge 間で割れた比較だけが human-review.md に出ている。
盲検（X/Y）で読んで human/<unit>.json を置き、次を実行すること:

  bin/analyze.sh          # 再集計 → 完了すれば結論が出る
  bin/publish.sh          # 公開物を docs/evaluation/axis2/ へ生成

計上できた累計（API 換算）: \$$(spent)
取得できない費用: $(unknown_costs)
（この数字は取得できた分の合計であって、総額の保証ではない）
EOF
[ "$FAILED" = 0 ] || echo "（判定に欠落がある。同じコマンドの再実行で埋まる）" | tee -a "$LOG"
