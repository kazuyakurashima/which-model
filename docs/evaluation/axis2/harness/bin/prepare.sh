#!/usr/bin/env bash
# 準備：タスク検証 → plan.json 作成 → A/B プロンプト生成 → 凍結（DESIGN.md §11）
#
# 使い方: bin/prepare.sh
# 環境変数:
#   CLAUDE_BIN  … claude の実体（既定 claude）。配管テストで偽物に差し替える
#   AXROOT      … 実験ルート（既定はこのスクリプトの2つ上）
#   GEN_MODEL   … config.json の gen_model を上書き
#
# 冪等：既にあるプロンプトは作り直さない。plan.json も作り直さない。
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
REPO="${WM_REPO:-$(cd "$AX/../.." && pwd)}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

py() { python3 "$LIB/$@"; }
cfgval() { python3 -c "import json,sys;print(json.load(open('$AX/config.json'))['$1'])"; }

echo "== 1) タスクの実行条件を検査 =="
py validate_tasks.py

echo "== 2) ディレクトリ =="
python3 -c "
import sys; sys.path.insert(0, '$LIB')
import common; common.ensure_dirs(); print('dirs: ok')"

echo "== 3) 実行計画（seed から決定論的に） =="
py make_plan.py

GEN_MODEL="${GEN_MODEL:-$(cfgval gen_model)}"
RETRY_MAX="$(cfgval retry_max)"
OUTFMT="$(cfgval output_format)"
SANDBOX="$(python3 -c "import sys; sys.path.insert(0, '$LIB'); import common; print(common.sandbox())")"
[ -d "$SANDBOX" ] || { echo "ERROR: sandbox を決められない" >&2; exit 1; }
FMT_ARGS=(--output-format "$OUTFMT")
[ "$OUTFMT" = "stream-json" ] && FMT_ARGS+=(--verbose)

echo "== 4) A プロンプト（素の依頼文をそのまま） =="
python3 -c "
import sys, pathlib; sys.path.insert(0, '$LIB')
import common
n = 0
for t in common.tasks():
    p = common.AX / 'prompts' / 'A' / (t['id'] + '.txt')
    if not p.exists():
        p.write_text(t['text'], encoding='utf-8'); n += 1
print(f'A prompts: {n} written')"

echo "== 5) B プロンプト（which-model 縮退経路。反復ごとに作り直す） =="
# plan.json の gen_order（シャッフル済み）に従う
python3 -c "
import json, sys; sys.path.insert(0, '$LIB')
import common
plan = json.loads((common.AX / 'plan.json').read_text(encoding='utf-8'))
by = common.task_by_id()
for g in plan['gen_order']:
    t = by[g['task']]
    print('\t'.join([t['id'], str(g['rep']), t['target_model'], t['target_effort']]))
" > "$AX/logs/_gen_order.tsv"

# GEN_LIMIT：**新規に生成する本数の上限**（未設定なら無制限）。
# plan.json の gen_order は seed で固定済みなので、**どれを・どの順で作るかは変わらない。**
# 区切って費用を確認するための一時停止であって、対象や採点基準には影響しない。
GEN_DONE=0
while IFS=$'\t' read -r ID REP TMODEL TEFFORT; do
  OUT="$AX/prompts/B/${ID}_r${REP}.txt"
  [ -s "$OUT" ] && { echo "skip (exists): B ${ID} r${REP}"; continue; }
  if [ -n "${GEN_LIMIT:-}" ] && [ "$GEN_DONE" -ge "${GEN_LIMIT}" ]; then
    echo "GEN_LIMIT=${GEN_LIMIT} に達した。ここで止める（同じコマンドで続きから再開できる）"
    break
  fi
  GEN_DONE=$((GEN_DONE + 1))
  RAW="$AX/prompts/A/${ID}.txt"
  T0=$(date +%s)
  ok=0
  for attempt in $(seq 0 "$RETRY_MAX"); do
    SID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    L1="$AX/logs/gen_${ID}_r${REP}_a${attempt}_phase1.log"
    L2="$AX/logs/gen_${ID}_r${REP}_a${attempt}_phase2.log"
    # 空 sandbox を cwd にする（repo 内で走らせると実ファイルを読みに行って汚染される）
    # --allowedTools Read が無いとフェーズ2に到達できない（ガイドを Read するため）
    # --bare は OAuth を読まないので使えない（2026-08-15 実測）
    (cd "$SANDBOX" && "$CLAUDE_BIN" --plugin-dir "$REPO/plugins/which-model" \
      --strict-mcp-config \
      --allowedTools Read --model "$GEN_MODEL" --session-id "$SID" \
      "${FMT_ARGS[@]}" -p "/which-model:pick $(cat "$RAW")" </dev/null) >"$L1" 2>&1 || true
    (cd "$SANDBOX" && "$CLAUDE_BIN" --plugin-dir "$REPO/plugins/which-model" \
      --strict-mcp-config \
      --allowedTools Read --model "$GEN_MODEL" --resume "$SID" \
      "${FMT_ARGS[@]}" -p "p model $TMODEL $TEFFORT" </dev/null) >"$L2" 2>&1 || true
    # 抽出は「最後の」マーカー対（入力側にマーカー文字列が混ざりうる。回帰テストの教訓）
    if py extract_marker.py "$L2" "最適化後プロンプト：" "主な調整点：" --stream \
         >"$OUT" 2>/dev/null && [ -s "$OUT" ]; then
      ok=1
      T1=$(date +%s)
      # 失敗した attempt のログも合算する（成功分だけ数えると実費を過小計上する）
      py record_gen.py "$AX/logs" "gen_${ID}_r${REP}" "$OUT" "$AX/gen/${ID}_r${REP}.json" \
        --task "$ID" --rep "$REP" --model "$GEN_MODEL" --effort "$TEFFORT" \
        --attempts "$((attempt + 1))" --elapsed "$((T1 - T0))"
      break
    fi
    rm -f "$OUT"
  done
  [ "$ok" = 1 ] || echo "WARN: B extract_failed: ${ID} r${REP}（logs/gen_${ID}_r${REP}_* を確認）" >&2
done < "$AX/logs/_gen_order.tsv"

echo "== 6) 完了ゲート =="
py gate.py gen

echo "== 6b) B プロンプトが狙ったモデル向けか =="
# エイリアスの解決先が経路で変わるため（S142）、生成物の『確定モデル：』を読んで確かめる。
py check_b_prompt.py

echo "== 7) 凍結（SHA-256。コード自体も含める） =="
# **初回だけ凍結する。** 既に manifest があれば照合し、不一致なら止まる。
# 再実行のたびに書き直すと、結果を見てから変えたコードが黙って再凍結される。
py freeze.py --ensure

cat <<EOF

準備完了。次は:
  bin/run.sh              # 回答の実行（plan.json の順・A/B ランダム）
  bin/grade-pairwise.sh   # blind pairwise 判定（左右入替2回）
  bin/analyze.sh          # 集計 → REPORT.md / human-review.md
EOF
