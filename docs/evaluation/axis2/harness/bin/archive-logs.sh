#!/usr/bin/env bash
# 再開前にログを退避する（DESIGN.md §7 の運用手順）。
#
# 使い方: bin/archive-logs.sh [パターン...]      既定は gen_* run_* judge_* judge2_*
#
# prepare.sh / run.sh / grade*.sh は再開時に**同じ試行番号から**ログ名を組み立てるため、
# 中断した試行のログを上書きする。上書きされると費用も原因も追えなくなる
# （2026-09-14 に実際に 1 試行ぶん失った）。**再開する前にこれを実行すること。**
#
# 退避するだけで削除はしない。費用集計は logs/ 直下だけを見るので、
# 退避したものは二重計上されない（退避先の内訳はこのスクリプトが一覧を出す）。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
PATTERNS=("$@")
[ ${#PATTERNS[@]} -eq 0 ] && PATTERNS=(gen_ run_ judge_ judge2_)
DEST="${AX}/logs/archive-$(date +%Y%m%d-%H%M%S)"

n=0
for pre in "${PATTERNS[@]}"; do
  for f in "${AX}"/logs/"${pre}"*; do
    [ -e "${f}" ] || continue
    mkdir -p "${DEST}"
    mv "${f}" "${DEST}/"
    n=$((n + 1))
  done
done

if [ "${n}" -eq 0 ]; then
  echo "退避するログはなかった"
else
  echo "ログ ${n} 件を退避した: ${DEST}"
  echo "**退避したぶんは費用集計の対象外になる。** 中断分の費用が必要なら、"
  echo "退避先のログから実測して probe.json の lost_attempts へ記録すること。"
fi
