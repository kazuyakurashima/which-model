#!/usr/bin/env bash
# 本実行前のプローブ（DESIGN.md §7 段 1a・1b）。**有料。**
#
# 使い方:
#   bin/probe-models.sh              # 未成功の部分だけを実行する
#   PROBE_REDO=fable,codex bin/...   # 成功済みでも指定した部分をやり直す
#
# 三つの原則:
#   1. **成功した部分は呼び直さない。** probe.json の parts.<name>.success を見る。
#   2. **1a が失敗したら 1b を呼ばずに停止する。** Fable 5.1 が使えない状態で
#      Codex を呼んでも本実行には進めないし、無駄に課金する。
#   3. **ログを上書きしない。** 試行ごとに時刻つきのファイルへ残す（費用集計が拾う）。
#
# **自動リトライはしない。** 失敗したら結果を残して非ゼロ終了する。
# **評価用の呼び出しでは MCP を無効化する**（--strict-mcp-config）。
# --mcp-config を渡さないので、読み込まれる MCP サーバーは 0 個になる。
# 利用者の MCP 設定・接続・認証は変更しない（呼び出し単位のフラグ）。
# 組み込みツール（Read/Grep/Glob）と --plugin-dir の which-model は従来どおり効く。
# 理由：接続済み MCP のツール定義が毎セッション十数万トークン入り、費用と実行条件を歪めるため。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX="${AXROOT:-$(cd "$HERE/.." && pwd)}"
export AXROOT="$AX"
LIB="${HERE}/lib"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CODEX_BIN="${CODEX_BIN:-codex}"
SANDBOX="$(python3 -c "import sys; sys.path.insert(0, '${LIB}'); import common; print(common.sandbox())")"
[ -d "${SANDBOX}" ] || { echo "ERROR: sandbox を決められない" >&2; exit 1; }
mkdir -p "${AX}/logs"
OUT="${AX}/probe.json"
TS="$(date +%Y%m%d-%H%M%S)"
REDO="${PROBE_REDO:-}"

# 試行ごとの通し番号。**同じ秒に再実行してもファイル名が衝突しない**ようにする
# （衝突すると前の試行を上書きし、費用集計から消える）。
next_idx() {  # next_idx <prefix> <suffix>
  n=0
  for _f in "${AX}"/logs/"$1"_*"$2"; do
    [ -e "${_f}" ] && n=$((n + 1))
  done
  printf "%03d" "$((n + 1))"
}

part_done() {  # part_done <name> → 成功済みなら 0
  case ",${REDO}," in *",$1,"*) return 1 ;; esac
  [ -s "${OUT}" ] || return 1
  python3 -c "
import json, sys
try:
    d = json.load(open('${OUT}'))
except Exception:
    sys.exit(1)
sys.exit(0 if (d.get('parts', {}).get('$1', {}).get('success') is True) else 1)
"
}

echo "== 1a) Fable 5.1 の疎通 =="
if part_done fable; then
  echo "  skip: 成功済み（probe.json の parts.fable。やり直すなら PROBE_REDO=fable）"
  FABLE_OK=yes
  FABLE_SKIPPED=1
  FABLE_ACTUAL="$(python3 -c "import json;print(json.load(open('${OUT}'))['parts']['fable'].get('actual_model',''))")"
else
  FABLE_SKIPPED=0
  FL="${AX}/logs/probe_fable51_$(next_idx probe_fable51 .log)_${TS}.log"  # **上書きしない**
  set +e
  (cd "${SANDBOX}" && "${CLAUDE_BIN}" --model claude-fable-5-1 --tools "" \
    --strict-mcp-config \
    --output-format stream-json --verbose -p "1+1 だけ答えてください。" </dev/null) \
    >"${FL}" 2>"${FL}.err"
  CLAUDE_RC=$?
  set -e
  read -r FABLE_OK FABLE_ACTUAL FABLE_STATUS <<EOF
$(python3 -c "
import sys; sys.path.insert(0, '${LIB}')
import parse_stream, pathlib
d = parse_stream.parse(pathlib.Path('${FL}').read_text(errors='replace'))
ok = 'yes' if (${CLAUDE_RC} == 0 and d['status'] == 'ok'
               and d['actual_model'] == 'claude-fable-5-1') else 'no'
print(ok, d['actual_model'] or 'none', d['status'])
")
EOF
  echo "  終了コード: ${CLAUDE_RC} ／ status: ${FABLE_STATUS} ／ 実測モデル: ${FABLE_ACTUAL}"
fi
echo "  Fable 5.1 が使えるか: ${FABLE_OK}"

# **実行したときだけ記録する。** skip のときは元の記録をそのまま残し、履歴も増やさない。
if [ "${FABLE_SKIPPED}" = 0 ]; then
  python3 "${LIB}/probe_record.py" "${AX}" --part fable \
    --success "${FABLE_OK}" --rc "${CLAUDE_RC}" --log "${FL}" \
    --actual-model "${FABLE_ACTUAL}" --status "${FABLE_STATUS}"
fi

if [ "${FABLE_OK}" != "yes" ]; then
  {
    echo ""
    echo "**Fable 5.1 が使えない。ここで停止する（Codex は呼ばない）。**"
    echo "  自動では Fable 5 に落とさない。回答側だけ 5 に落とすと、"
    echo "  B プロンプトは 5.1 向けのまま生成されて食い違う。"
    echo "  落とすかどうかは利用者が決め、tasks.json の model_id を書き換えてから再実行すること。"
  } >&2
  python3 - "${AX}" >&2 <<'PY'
import json, pathlib, sys
ax = pathlib.Path(sys.argv[1])
t = json.loads((ax / "tasks.json").read_text(encoding="utf-8"))
downgraded = [x["id"] for x in t["tasks"] if x.get("model_id") == "claude-fable-5"]
if downgraded or t.get("_fallback_note"):
    print("  **注意：tasks.json が既に書き換わっている（このスクリプトは戻さない）。**")
    if downgraded:
        print(f"  claude-fable-5 のタスク: {', '.join(downgraded)}")
for d in ("prompts/B", "gen", "outputs", "judgements", "judgements2"):
    n = len(list((ax / d).glob("*"))) if (ax / d).is_dir() else 0
    if n:
        print(f"  既存データ: {d} に {n} 件（削除していない）")
PY
  exit 1
fi

echo "== 1b) Codex の --json イベント形 =="
if part_done codex; then
  echo "  skip: 成功済み（probe.json の parts.codex。やり直すなら PROBE_REDO=codex）"
  python3 "${LIB}/probe_record.py" "${AX}" --finalize
  exit $?
fi
CL="${AX}/logs/probe_codex_$(next_idx probe_codex .jsonl)_${TS}.jsonl"
CLAST="${CL%.jsonl}.last.txt"
rm -f "${CLAST}"                                  # 古い last-message を拾わない
JUDGE2_MODEL="$(python3 -c "import json;print(json.load(open('${AX}/config.json'))['judge2_model'])")"
JUDGE2_EFFORT="$(python3 -c "import json;print(json.load(open('${AX}/config.json'))['judge2_effort'])")"
set +e
"${CODEX_BIN}" exec --ignore-user-config -m "${JUDGE2_MODEL}" \
  -c "model_reasoning_effort=\"${JUDGE2_EFFORT}\"" \
  --sandbox read-only -C "${AX}" --skip-git-repo-check --ephemeral --json --color never \
  -o "${CLAST}" --output-schema "${LIB}/judge_schema.json" \
  "このディレクトリに DESIGN.md があるか、ファイルを一覧して確かめてください。確認したら verdict=tie、reason に確認方法、evidence にファイル名を入れて返してください。" \
  </dev/null >"${CL}" 2>"${CL}.err"
CODEX_RC=$?
set -e
echo "  終了コード: ${CODEX_RC}"

python3 "${LIB}/probe_record.py" "${AX}" --part codex \
  --rc "${CODEX_RC}" --log "${CL}" --last "${CLAST}"
python3 "${LIB}/probe_record.py" "${AX}" --finalize
