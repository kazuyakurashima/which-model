#!/usr/bin/env bash
# 集計：results.csv / REPORT.md / human-review.md / review/ を出す（LLM を使わない・無料）。
#
# 使い方: bin/analyze.sh
# 人間確認を human/<unit>.json に置いてから再実行すると、確定値が更新される。
#
# **凍結照合してから走る。** 集計ロジックを結果確認後に変えられると、
# 停止規則を事前凍結した意味が無くなる（DESIGN.md §11）。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
python3 "$HERE/lib/freeze.py" --check
python3 "$HERE/lib/analyze.py"
