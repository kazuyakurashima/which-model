#!/usr/bin/env bash
# 配管テスト（**無料**。偽 claude を使うのでモデルを一切呼ばない）。
#
# 使い方: bin/selftest.sh
#
# 一時ディレクトリに実験ルートを丸ごと組み立て、prepare → run → grade → analyze を
# 通してから、期待する不変条件を検査する。本番の .work/axis2-v2/ は汚さない。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$SRC/../.." && pwd)"

TMP="$(mktemp -d)"
# KEEP=1 を付けると生成物を残す（REPORT.md 等を目視したいとき）
if [ "${KEEP:-0}" = "1" ]; then
  trap 'echo "生成物: $TMP/ax"' EXIT
else
  trap 'rm -rf "$TMP"' EXIT
fi
AX="$TMP/ax"
mkdir -p "$AX/bin" "$AX/tests" "$TMP/fixture-workdir"
echo "fixture" > "$TMP/fixture-workdir/README.md"

cp -R "$SRC/bin/." "$AX/bin/"
cp "$SRC/tests/fake-claude.py" "$SRC/tests/fake-codex.py" "$AX/tests/"
cp -R "$SRC/tests/fixtures" "$AX/tests/"
cp "$SRC/DESIGN.md" "$SRC/STOP-RULES.md" "$AX/"
chmod +x "$AX/bin/"*.sh "$AX/tests/fake-claude.py"

# config：本番の値を使うが、**反復は 2 に固定する**。
# 反復ごとの B 再生成・反復間の勝敗逆転を検査する必要があり、本番が reps=1 でも
# 配管としては 2 を通しておく。seed は本番と同じ。
python3 - "$SRC/config.json" "$AX/config.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
c["reps"] = 2
c.pop("sandbox_dir", None)   # 本番の sandbox を配管テストで使わない
json.dump(c, open(sys.argv[2], "w"), ensure_ascii=False, indent=2)
PY

python3 - "$SRC/tests/tasks.fixture.json" "$AX/tasks.json" "$TMP/fixture-workdir" <<'PY'
import json, sys
src, dst, wd = sys.argv[1:4]
t = json.load(open(src))
for x in t["tasks"]:
    if x["workdir"] == "__FIXTURE_WORKDIR__":
        x["workdir"] = wd
json.dump(t, open(dst, "w"), ensure_ascii=False, indent=2)
PY

export AXROOT="$AX"
export CLAUDE_BIN="$AX/tests/fake-claude.py"
export CODEX_BIN="$AX/tests/fake-codex.py"
export WM_REPO="$REPO"

echo "########## prepare ##########"
"$AX/bin/prepare.sh"
echo "########## run ##########"
"$AX/bin/run.sh"
echo "########## grade-pairwise（Claude） ##########"
"$AX/bin/grade-pairwise.sh"
echo "########## grade2-codex（第2 judge） ##########"
"$AX/bin/grade2-codex.sh"
echo "########## analyze ##########"
"$AX/bin/analyze.sh"


echo "########## 不変条件の検査 ##########"
python3 - "$AX" <<'PYEOF'
import json, os, pathlib, subprocess, sys
ax = pathlib.Path(sys.argv[1])
fail = []
env = {**os.environ, "AXROOT": str(ax)}


def ck(cond, msg):
    print(("ok   " if cond else "FAIL ") + msg)
    if not cond:
        fail.append(msg)


def sh(script, *args, extra_env=None):
    e = dict(env)
    if extra_env:
        e.update(extra_env)
    return subprocess.run([str(ax / "bin" / script), *args],
                          capture_output=True, text=True, env=e)


plan = json.loads((ax / "plan.json").read_text())
runs = {p.stem: json.loads(p.read_text()) for p in (ax / "outputs").glob("*.json")}
j1 = [json.loads(p.read_text()) for p in (ax / "judgements").glob("*.json")]
j2 = [json.loads(p.read_text()) for p in (ax / "judgements2").glob("*.json")]
report = (ax / "REPORT.md").read_text()
review = (ax / "human-review.md").read_text()

print("-- 規模 --")
ck(len(runs) == 16, f"run が 4タスク×2腕×2反復＝16 件（実際 {len(runs)}）")
ck(all(r["status"] == "ok" for r in runs.values()), "全 run が status=ok")
ck(len(j1) == 16, f"Claude judge の判定が 16 件（実際 {len(j1)}）")
ck(len(j2) == 16, f"Codex judge の判定が 16 件（実際 {len(j2)}）")
ck(all(x["judge_family"] == "codex" for x in j2), "judgements2 に judge_family=codex が入る")

print("-- 実モデル ID の記録と突き合わせ --")
ck(all(r.get("expect_model") for r in runs.values()), "全 run に expect_model がある")
ck(all(r.get("actual_model") == r.get("expect_model") for r in runs.values()),
   "全 run で actual_model が expect_model と一致している")
ck(runs["f03_A_r1"]["expect_model"] == "claude-fable-5-1",
   "fable タスクの指定がフル ID（claude-fable-5-1）になっている")
ck("## 5. 実際に使われたモデル" in report, "REPORT に実モデルの節がある")

print("-- B プロンプトが狙ったモデル向けか --")
b = sorted(p.name for p in (ax / "prompts" / "B").glob("*.txt"))
ck(len(b) == 8, f"B プロンプトが 4タスク×2反復＝8 本（実際 {len(b)}）")
rc = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "check_b_prompt.py")],
                    capture_output=True, text=True, env=env)
ck(rc.returncode == 0, "check_b_prompt が全 B プロンプトを合格させる")
# 確定モデルの行に日本語が続いても偽の不一致にしない（2026-09-14 の取りこぼし）
sys.path.insert(0, str(ax / "bin" / "lib"))
import check_b_prompt as _cbp  # noqa: E402
_line = "確定モデル：Sonnet 5 / effort=medium（あなたの指定として受理しました）"
ck(_cbp.CONFIRM_RE.findall(_line) == [("Sonnet 5", "medium")],
   "**B 検査：effort の直後に日本語が続いても正しく切り出す**")

# 確定モデルが違う生成ログに差し替えると検出するか
log = sorted((ax / "logs").glob("gen_f03_r1_a*_phase2.log"))[-1]
keep = log.read_text()
log.write_text(keep.replace("Fable 5.1", "Fable 5"))
rc = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "check_b_prompt.py")],
                    capture_output=True, text=True, env=env)
ck(rc.returncode != 0 and "確定モデルが狙いと違う" in rc.stderr,
   "B プロンプトが別世代向けだと check_b_prompt が止める")
log.write_text(keep)

print("-- judge 間の一致・不一致の扱い --")
ck("## 2. judge 間の一致（Claude / Codex）" in report, "REPORT に judge 間一致の節がある")
# f01: 両系統 B 一致 → 自動確定 ／ f03: 両系統 B＋A に critical 一致 → 自動確定
ck("| f01 | B / B | **B** |" in report, "f01 は両 judge 一致で B に自動確定")
ck("| f03 | B / B | **B** |" in report, "f03 は両 judge 一致で B に自動確定")
# f02: Claude unresolved・Codex B → 不一致 ／ f04: Claude B・Codex A → 不一致
ck("## f02_r1" in review and "## f04_r1" in review,
   "judge 間で割れた比較単位が人間確認へ抽出される")
ck("## f01_r1" not in review and "## f03_r1" not in review,
   "一致した比較単位は人間確認へ回さない（無作為抽出を廃止した）")
ck("judge 間の不一致" in review, "抽出理由が judge 間の不一致であることが示される")
ck("無作為" not in review.replace("無作為抽出は v3 では行わない", ""),
   "human-review.md が無作為抽出を持ち出していない")

print("-- critical error は両系統一致のときだけ確定 --")
ck("| A（素の依頼） | 2 | 0 |" in report,
   "f03 の2反復で A に確定 critical が 2 件（両系統一致）")
ck("片方だけ（未確定）" in report, "未確定 critical の欄がある")

print("-- 完了ゲート --")
ck("**状態：INCOMPLETE / 判定保留**" in report, "不一致が未確認の段階では INCOMPLETE")
ck("判定：**INCOMPLETE / 判定保留**" in report, "停止規則を適用した結論を出していない")
ck("### 判定：**価値信号なし**" not in report
   and "### 判定：**価値信号あり" not in report
   and "### 判定：**判定不能" not in report,
   "未完了の段階で結論の見出しを出していない")
rc = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "gate.py"), "judge2"],
                    capture_output=True, text=True, env=env)
ck(rc.returncode == 0, "judge2 の完了ゲートが通る")
p = ax / "judgements2" / sorted(x.name for x in (ax / "judgements2").glob("*.json"))[0]
keep2 = p.read_text(); p.unlink()
rc = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "gate.py"), "judge2"],
                    capture_output=True, text=True, env=env)
ck(rc.returncode != 0 and "judgements2" in rc.stderr,
   "judge2 の欠損を完了ゲートが検出する")
p.write_text(keep2)

print("-- ツール0回の判定を採用しないか（両系統で同じ基準） --")
fx = ax / "tests" / "fixtures"
notool = ax / "logs" / "_fx_notool.log"
notool.write_text(json.dumps({"type": "system", "subtype": "init",
                              "session_id": "s", "model": "claude-sonnet-5"}) + "\n"
                  + json.dumps({"type": "result", "subtype": "success",
                                "is_error": False,
                                "result": '{"verdict":"left_better","reason":"r",'
                                          '"evidence":"e"}',
                                "total_cost_usd": 0.01, "duration_ms": 100,
                                "num_turns": 1, "permission_denials": []}) + "\n")
rc = subprocess.run(
    [sys.executable, str(ax / "bin" / "lib" / "parse_judgement.py"),
     str(notool), "f01", "1", "AB", str(ax / "logs" / "_fx_j.json")],
    capture_output=True, text=True, env=env)
ck(rc.returncode != 0 and "ツールを使っていない" in rc.stderr,
   "Claude judge：context_required でツール0回の判定を採用しない")
codex_notool = ax / "logs" / "_fx_codex_notool.jsonl"
codex_last = ax / "logs" / "_fx_codex_notool.last.txt"
codex_notool.write_text(json.dumps({"type": "session.created"}) + "\n"
                        + json.dumps({"type": "turn.completed"}) + "\n")
codex_last.write_text('{"verdict":"left_better","reason":"r","evidence":"e"}')
rc = subprocess.run(
    [sys.executable, str(ax / "bin" / "lib" / "judge2_codex.py"),
     str(codex_notool), str(codex_last), "f01", "1", "AB",
     str(ax / "logs" / "_fx_j2.json")],
    capture_output=True, text=True, env=env)
ck(rc.returncode != 0 and "ツールを使っていない" in rc.stderr,
   "Codex judge：context_required でツール0回の判定を採用しない")

print("-- 写像が2系統で共有されているか --")
sys.path.insert(0, str(ax / "bin" / "lib"))
import parse_judgement as pj  # noqa: E402
import judge2_codex as jc     # noqa: E402
ck(jc.parse_judgement.to_arms is pj.to_arms, "Codex 側が Claude 側の写像関数を共有している")

print("-- 実行条件が A/B で揃っているか --")
for t in ("f01", "f02", "f03", "f04"):
    for r in (1, 2):
        a, bb = runs[f"{t}_A_r{r}"], runs[f"{t}_B_r{r}"]
        ck(a["workdir"] == bb["workdir"] and a["allowed_tools"] == bb["allowed_tools"]
           and a["model"] == bb["model"] and a["effort"] == bb["effort"],
           f"{t} r{r}: A/B が同一の workdir・ツール・モデル・effort")
bb = runs["f01_B_r1"]
ck(bb["gen_cost_usd"] is not None and bb["total_cost_usd"] > bb["answer_cost_usd"],
   "B の合計コストにプロンプト生成費用が加算されている")
ck(runs["f01_A_r1"]["gen_cost_usd"] is None, "A に生成費用が付いていない")
ck(all(runs[f"f02_{a}_r{r}"]["tool_calls"] == 0 for a in "AB" for r in (1, 2)),
   "f02（context_required=false）はツール呼び出し 0 回")
ck(runs["f02_A_r1"]["workdir"].endswith("/sandbox"), "f02 の workdir は空 sandbox")

print("-- ランダム化 --")
seq = [f"{x['task']}_{x['arm']}_{x['rep']}" for x in plan["run_order"]]
naive = [f"{t}_{a}_{r}" for t in plan["tasks"] for a in ("A", "B") for r in (1, 2)]
ck(seq != naive, "run_order が素直な A→B 固定順になっていない")
ck(sorted(seq) == sorted(naive), "run_order が全組み合わせを過不足なく含む")
ck(all(set(v) == {"AB", "BA"} for v in plan["judge_orders"].values()),
   "各比較単位の提示順が AB / BA の対")
ck(any(plan["blind_map"][u] != plan["judge_orders"][u][0] for u in plan["blind_map"]),
   "盲検割当が judge の提示順と別の抽選になっている")

print("-- judge プロンプトが系統ごとに切り替わるか --")
gp1 = list((ax / "logs").glob("judge_f01_*_prompt.txt"))
gp2 = list((ax / "logs").glob("judge2_f01_*_prompt.txt"))
ck(gp1 and all("Read` / `Grep` / `Glob` で実装を読めます" in p.read_text() for p in gp1),
   "Claude 版 judge プロンプトが実装照合版（Read/Grep/Glob）")
ck(gp2 and all("読み取り専用のシェル" in p.read_text() for p in gp2),
   "Codex 版 judge プロンプトが読み取り専用シェル版")
ck(gp2 and all("which-model" not in p.read_text() for p in gp2),
   "Codex 版 judge プロンプトに which-model の存在が漏れていない")
gp2b = list((ax / "logs").glob("judge2_f02_*_prompt.txt"))
ck(gp2b and all("読み取り専用のシェル" not in p.read_text() for p in gp2b),
   "context_required=false の Codex プロンプトは通常版")

print("-- 盲検資料 --")
ck("outputs/" not in review, "human-review.md に腕入りのファイル名が出ていない")
ck("A=素の依頼" not in review and "B=which-model" not in review,
   "human-review.md が腕の対応を開示していない")
for u in ("f02_r1", "f04_r1"):
    d = ax / "review" / u
    ck((d / "X.md").is_file() and (d / "Y.md").is_file(),
       f"{u}: 盲検の X.md / Y.md が書き出されている")
xs = (ax / "review" / "f02_r1" / "X.md").read_text()
ck("which-model" not in xs, "review の本文に腕ラベルの説明が付いていない")

print("-- 異常応答 --")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "parse_stream", ax / "bin" / "lib" / "parse_stream.py")
ps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ps)
d_err = ps.parse((fx / "is_error.log").read_text())
ck(d_err["result"] != "" and d_err["status"] == "error_result",
   "is_error=true は本文があっても status=ok にしない")

tmpout = ax / "outputs" / "_fixture_probe.json"


def rec(log, tools, expect=None):
    args = [sys.executable, str(ax / "bin" / "lib" / "record_run.py"), str(log), str(tmpout),
            "--task", "f01", "--arm", "A", "--rep", "1", "--model", "claude-sonnet-5",
            "--effort", "high", "--prompt-file", str(ax / "prompts" / "A" / "f01.txt"),
            "--workdir", str(ax), "--tools", tools, "--claude-version", "fake",
            "--elapsed", "1", "--rc", "0"]
    if expect:
        args += ["--expect-model", expect]
    r = subprocess.run(args, capture_output=True, text=True, env=env)
    return json.loads(tmpout.read_text()), r


d, r = rec(fx / "is_error.log", "Read Grep Glob")
ck(d["status"] == "error_result" and r.returncode != 0,
   "record_run が is_error の応答を失敗として書き出す")
d, r = rec(fx / "denied_granted.log", "Read Grep Glob")
ck(d["status"] == "permission_denied_on_granted_tool",
   "与えたはずの Read が拒否された run を失敗扱いにする")
d, r = rec(fx / "denied_ungranted.log", "Read Grep Glob")
ck(d["status"] == "ok" and d["denied_tools"] == ["Bash"],
   "与えていない Bash への拒否は想定内として ok のまま記録する")
d, r = rec(fx / "denied_ungranted.log", "Read Grep Glob", expect="claude-fable-5-1")
ck(d["status"] in ("model_mismatch", "actual_model_unknown"),
   f"期待と違うモデルの run を ok にしない（status={d['status']}）")
tmpout.unlink()

print("-- 今回直した不具合の異常系 --")

# (3) Codex：終了コードが非0の実行を採用しない
codex_ok_log = ax / "logs" / "_fx_codex_ok.jsonl"
codex_ok_last = ax / "logs" / "_fx_codex_ok.last.txt"
codex_ok_log.write_text(
    json.dumps({"type": "session.created"}) + "\n"
    + json.dumps({"type": "item.completed", "item": {"item_type": "command_execution"}}) + "\n"
    + json.dumps({"type": "turn.completed", "usage": {"input_tokens": 1}}) + "\n")
codex_ok_last.write_text('{"verdict":"left_better","reason":"r","evidence":"e"}')


def run_j2(rc=None, log=None, last=None, out_name="_fx_j2.json"):
    args = [sys.executable, str(ax / "bin" / "lib" / "judge2_codex.py"),
            str(log or codex_ok_log), str(last or codex_ok_last),
            "f01", "1", "AB", str(ax / "logs" / out_name)]
    if rc is not None:
        args += ["--rc", str(rc)]
    return subprocess.run(args, capture_output=True, text=True, env=env)


r = run_j2(rc=0)
ck(r.returncode == 0, "Codex：rc=0・完了イベントあり・ツールありなら採用する")
r = run_j2(rc=1)
ck(r.returncode != 0 and "終了コード" in r.stderr,
   "Codex：終了コードが非0の実行を採用しない（判定 JSON があっても）")

# (3) Codex：正常完了イベントが無い実行を採用しない
cut_log = ax / "logs" / "_fx_codex_cut.jsonl"
cut_log.write_text(
    json.dumps({"type": "session.created"}) + "\n"
    + json.dumps({"type": "item.completed", "item": {"item_type": "command_execution"}}) + "\n")
r = run_j2(rc=0, log=cut_log)
ck(r.returncode != 0 and "正常完了していない" in r.stderr,
   "Codex：正常完了イベントが無い（途中で切れた）実行を採用しない")

# (3) Codex：エラーイベントがある実行を採用しない
err_log = ax / "logs" / "_fx_codex_err.jsonl"
err_log.write_text(codex_ok_log.read_text()
                   + json.dumps({"type": "stream.error"}) + "\n")
r = run_j2(rc=0, log=err_log)
ck(r.returncode != 0 and "エラーイベント" in r.stderr,
   "Codex：エラーイベントがある実行を採用しない")

# (3) Codex：last-message が無ければ採用しない（古いファイルの使い回しを防ぐ側の対）
r = run_j2(rc=0, last=ax / "logs" / "_fx_does_not_exist.txt")
ck(r.returncode != 0, "Codex：last-message が無い実行を採用しない")
ck("rm -f \"$GLAST\"" in (ax / "bin" / "grade2-codex.sh").read_text(),
   "grade2-codex.sh が試行前に古い last-message を消している")

# (1) probe：失敗した probe.json を成功扱いで使い回さない
probe_sh = (ax / "bin" / "probe-models.sh").read_text()
ck("part_done" in probe_sh and "parts" in probe_sh,
   "probe：部分ごとの success を見て skip する（probe.json の存在だけで skip しない）")
ck("${FABLE_OK}" in probe_sh and "${FABLE_ACTUAL}" in probe_sh,
   "probe：全角文字に隣接する変数を ${...} で区切っている")

# (2) probe：Fable 5.1 が使えないとき自動降格しない
ck('model_id"] = "claude-fable-5"' not in probe_sh
   and '"tasks.json").write_text' not in probe_sh,
   "probe：Fable 5.1 が使えなくても tasks.json を書き換えない")
ck("削除していない" in probe_sh, "probe：既存データを削除せず件数を報告する")
# **挙動で検査する。** 偽の実行体を使い、Fable が失敗したとき Codex を呼ばないことを見る。
pax = ax / "_probe_ax"
(pax / "logs").mkdir(parents=True, exist_ok=True)
(pax / "sandbox").mkdir(exist_ok=True)
(pax / "bin" / "lib").mkdir(parents=True, exist_ok=True)
(pax / "bin" / "probe-models.sh").write_bytes((ax / "bin" / "probe-models.sh").read_bytes())
(pax / "bin" / "probe-models.sh").chmod(0o755)
for p in (ax / "bin" / "lib").glob("*"):
    if p.is_file():
        (pax / "bin" / "lib" / p.name).write_bytes(p.read_bytes())
(pax / "config.json").write_text(json.dumps({"judge2_model": "fake", "judge2_effort": "high"}))
(pax / "tasks.json").write_text(json.dumps({"tasks": []}))

marker = pax / "logs" / "_codex_was_called"
fake_cx = pax / "fake_codex_marker.sh"
fake_cx.write_text("#!/bin/sh\ntouch '%s'\nexit 1\n" % marker)
fake_cx.chmod(0o755)


def fake_claude(model_line):
    p = pax / "fake_claude_probe.py"
    p.write_text(
        "#!/usr/bin/env python3\n"
        "import json\n"
        "print(json.dumps({'type':'system','subtype':'init','session_id':'s',"
        "'model':%r}))\n"
        "print(json.dumps({'type':'result','subtype':'success','is_error':False,"
        "'result':'2','total_cost_usd':0.01,'duration_ms':10,'num_turns':1,"
        "'permission_denials':[],'usage':{'output_tokens':1}}))\n" % model_line)
    p.chmod(0o755)
    return p


penv = {**os.environ, "AXROOT": str(pax),
        "CLAUDE_BIN": str(fake_claude("claude-fable-5")),
        "CODEX_BIN": str(fake_cx)}
marker.unlink(missing_ok=True)
(pax / "probe.json").unlink(missing_ok=True)
r = subprocess.run([str(pax / "bin" / "probe-models.sh")],
                   capture_output=True, text=True, env=penv)
ck(r.returncode != 0, "probe：Fable 5.1 が使えないとき非ゼロ終了する")
ck(not marker.exists(), "**probe：Fable 失敗時に Codex を呼ばない（挙動で確認）**")
ck("ここで停止する" in r.stderr, "probe：停止した旨を出す")
pj = json.loads((pax / "probe.json").read_text())
ck(pj["parts"]["fable"]["success"] is False, "probe：fable の失敗が parts に記録される")
ck("codex" not in pj["parts"], "probe：呼んでいない Codex の記録を作らない")

penv["CLAUDE_BIN"] = str(fake_claude("claude-fable-5-1"))
(pax / "probe.json").unlink(missing_ok=True)
marker.unlink(missing_ok=True)
subprocess.run([str(pax / "bin" / "probe-models.sh")], capture_output=True, text=True, env=penv)
ck(marker.exists(), "probe：Fable 成功なら Codex を呼ぶ")
n1 = len(list((pax / "logs").glob("probe_fable51_*.log")))
marker.unlink(missing_ok=True)
r2 = subprocess.run([str(pax / "bin" / "probe-models.sh")],
                    capture_output=True, text=True, env=penv)
n2 = len(list((pax / "logs").glob("probe_fable51_*.log")))
ck("skip: 成功済み" in r2.stdout, "probe：成功済みの Claude を呼び直さない")
ck(n2 == n1, "probe：skip 時に Claude のログが増えない（＝呼んでいない）")
ck(marker.exists(), "probe：失敗した部分（Codex）は再実行される")
n_cx = len(list((pax / "logs").glob("probe_codex_*.jsonl")))
ck(n_cx >= 2, f"probe：試行ごとにログを残す（上書きしない。Codex ログ {n_cx} 本）")
hist = json.loads((pax / "probe.json").read_text()).get("history", [])
ck(len([h for h in hist if h["part"] == "codex"]) >= 2, "probe：試行が history に積まれる")

# 修正1：skip した部分は記録・履歴を触らない
pj_before = json.loads((pax / "probe.json").read_text())
fable_rec_before = pj_before["parts"]["fable"]
n_hist_before = len(pj_before.get("history", []))
subprocess.run([str(pax / "bin" / "probe-models.sh")], capture_output=True, text=True, env=penv)
pj_after = json.loads((pax / "probe.json").read_text())
ck(pj_after["parts"]["fable"] == fable_rec_before,
   "probe：skip した部分の記録（ログ参照・費用・日時）が変わらない")
n_fable_hist = len([h for h in pj_after.get("history", []) if h["part"] == "fable"])
ck(n_fable_hist == len([h for h in pj_before.get("history", []) if h["part"] == "fable"]),
   "probe：skip した部分は history を増やさない")

# 修正1：実際に試行したら、最新の失敗が現在の判定になる（過去の成功で隠さない）
penv2 = dict(penv)
penv2["CLAUDE_BIN"] = str(fake_claude("claude-fable-5"))   # 今度は失敗させる
penv2["PROBE_REDO"] = "fable"
r3 = subprocess.run([str(pax / "bin" / "probe-models.sh")],
                    capture_output=True, text=True, env=penv2)
pj3 = json.loads((pax / "probe.json").read_text())
ck(pj3["parts"]["fable"]["success"] is False,
   "**probe：再試行した部分は最新の失敗が現在の判定になる（過去の成功で隠さない）**")
ck(r3.returncode != 0, "probe：最新が失敗なら非ゼロ終了する")

# 修正2：評価用の Claude 呼び出しに --strict-mcp-config が入っている
for name in ("probe-models.sh", "prepare.sh", "run.sh", "grade-pairwise.sh"):
    body = (ax / "bin" / name).read_text()
    ck("--strict-mcp-config" in body, f"MCP 無効化：{name} に --strict-mcp-config がある")
prep = (ax / "bin" / "prepare.sh").read_text()
ck(prep.count("--strict-mcp-config") >= 3,
   "MCP 無効化：B 生成の 2 往復とも対象になっている")
ck("--plugin-dir" in prep, "MCP 無効化：which-model プラグインの読み込みは残っている")
# コメント行を除いた実行部分だけを見る（説明文の中の語を拾わないため）
run_code = "\n".join(ln for ln in (ax / "bin" / "run.sh").read_text().splitlines()
                      if not ln.strip().startswith("#"))
ck("--mcp-config" not in run_code.replace("--strict-mcp-config", ""),
   "MCP 無効化：--mcp-config を渡していない（＝MCP サーバー 0 個）")
gr = (ax / "bin" / "grade-pairwise.sh").read_text()
ck("JT_ARGS" in gr and "--strict-mcp-config" in gr,
   "MCP 無効化：judge のツール指定は維持したまま MCP だけ切っている")

# 偽 claude に渡った引数を記録して、実際にフラグが渡ることを挙動で確かめる
argsdump = pax / "logs" / "_claude_args.txt"
spy = pax / "fake_claude_spy.py"
spy.write_text(
    "#!/usr/bin/env python3\n"
    "import json, sys\n"
    "open(%r, 'a').write(' '.join(sys.argv[1:]) + '\\n')\n"
    "print(json.dumps({'type':'system','subtype':'init','session_id':'s',"
    "'model':'claude-fable-5-1'}))\n"
    "print(json.dumps({'type':'result','subtype':'success','is_error':False,"
    "'result':'2','total_cost_usd':0.01,'duration_ms':10,'num_turns':1,"
    "'permission_denials':[],'usage':{'output_tokens':1}}))\n" % str(argsdump))
spy.chmod(0o755)
argsdump.unlink(missing_ok=True)
penv3 = dict(penv); penv3["CLAUDE_BIN"] = str(spy); penv3["PROBE_REDO"] = "fable"
subprocess.run([str(pax / "bin" / "probe-models.sh")], capture_output=True, text=True, env=penv3)
ck(argsdump.is_file() and "--strict-mcp-config" in argsdump.read_text(),
   "**MCP 無効化：実際に claude へ --strict-mcp-config が渡っている（挙動で確認）**")

# 修正1：移行前の Codex 試行が「費用不明」に含まれる（推定と二重計上しない）
(pax / "probe.json").write_text(json.dumps({
    "parts": {}, "history": [],
    "lost_attempts": [
        {"what": "Codex プローブ 1 試行", "estimated_usd": None, "basis": "400 で拒否"},
        {"what": "Claude プローブ 1 試行", "estimated_usd": 2.806, "basis": "同条件の2回目"}],
}, ensure_ascii=False))
sys.path.insert(0, str(ax / "bin" / "lib"))
import importlib
import sum_cost as _sc
importlib.reload(_sc)
unk = _sc.unknown(str(pax))
ck(any("Codex" in u and "記録が失われた分 1" in u for u in unk),
   "費用：移行前の Codex 試行が『費用不明』に含まれる")
lost_est = sum(x.get("estimated_usd") or 0 for x in _sc.lost(str(pax)))
ck(abs(lost_est - 2.806) < 1e-6,
   "費用：金額が推定できる分は推定側だけで数える（不明側と二重計上しない）")

# 費用：history に付け漏れがあってもログがあれば数える（2026-09-10 の過少計上の再発防止）
import re as _re


def codex_unknown_count(root):
    importlib.reload(_sc)
    for u in _sc.unknown(str(root)):
        m = _re.search(r"Codex (\d+) 試行", u)
        if m:
            return int(m.group(1))
    return 0


before = codex_unknown_count(pax)
# history には載せず、ログだけを 2 本増やす
for name in ("probe_codex_900_x.jsonl", "probe_codex_901_x.jsonl"):
    (pax / "logs" / name).write_text(
        json.dumps({"type": "thread.started"}) + "\n"
        + json.dumps({"type": "turn.completed"}) + "\n")
after = codex_unknown_count(pax)
hist_codex = len([h for h in json.loads((pax / "probe.json").read_text()).get("history", [])
                  if h.get("part") == "codex"])
ck(after == before + 2,
   f"**費用：history に無いログも数える（{before} → {after}）**")
ck(after > hist_codex,
   f"費用：history の件数（{hist_codex}）に縛られず、ログの実数で数える")

# 費用：gen/*.json が無い（中断した）B 生成の試行も計上する
before_total = float(subprocess.run(
    [sys.executable, str(ax / "bin" / "lib" / "sum_cost.py"), str(ax), "--total"],
    capture_output=True, text=True, env=env).stdout.strip())
(ax / "logs" / "gen_zzz_orphan_r1_a0_phase1.log").write_text(
    json.dumps({"type": "system", "subtype": "init", "session_id": "s"}) + "\n"
    + json.dumps({"type": "result", "subtype": "success", "is_error": False,
                  "result": "x", "total_cost_usd": 0.25, "duration_ms": 1,
                  "num_turns": 1, "permission_denials": []}) + "\n")
after_total = float(subprocess.run(
    [sys.executable, str(ax / "bin" / "lib" / "sum_cost.py"), str(ax), "--total"],
    capture_output=True, text=True, env=env).stdout.strip())
ck(abs((after_total - before_total) - 0.25) < 1e-6,
   f"**費用：中断した B 生成の試行も計上する（{before_total:.3f} → {after_total:.3f}）**")

# 費用：作り直しで退避した試行（archive/*/cost.json）も数え続ける
(ax / "archive" / "_fx").mkdir(parents=True, exist_ok=True)
(ax / "archive" / "_fx" / "cost.json").write_text(json.dumps({"usd": 1.5}))
arch_total = float(subprocess.run(
    [sys.executable, str(ax / "bin" / "lib" / "sum_cost.py"), str(ax), "--total"],
    capture_output=True, text=True, env=env).stdout.strip())
ck(abs((arch_total - after_total) - 1.5) < 1e-6,
   f"**費用：退避した試行の費用を合計に残す（{after_total:.3f} → {arch_total:.3f}）**")

# sandbox：sandbox_dir を使い、親に CLAUDE.md がある場所は拒否する
# **config.json は凍結対象なので、元のバイト列を保存して最後にそのまま戻す**
# （json.dumps で書き直すとハッシュが変わり、以降の凍結照合がすべて落ちる）
import common as _common  # noqa: E402
_cfg_bytes = (ax / "config.json").read_bytes()
_sb = ax / "_sb_ok"
(ax / "config.json").write_text(json.dumps({**json.loads((ax / "config.json").read_text()),
                                            "sandbox_dir": str(_sb)}))
importlib.reload(_common)
ck(_common.sandbox() == _sb, "sandbox：config.json の sandbox_dir を使う")
_bad = ax / "_repo_like" / "sub" / "sandbox"
(ax / "_repo_like").mkdir(exist_ok=True)
(ax / "_repo_like" / "CLAUDE.md").write_text("dev rules")
(ax / "config.json").write_text(json.dumps({**json.loads((ax / "config.json").read_text()),
                                            "sandbox_dir": str(_bad)}))
importlib.reload(_common)
try:
    _common.sandbox()
    ck(False, "**sandbox：親に CLAUDE.md がある場所を拒否する**")
except SystemExit as e:
    ck("CLAUDE.md" in str(e), "**sandbox：親に CLAUDE.md がある場所を拒否する**")
(ax / "config.json").write_bytes(_cfg_bytes)
importlib.reload(_common)
ck((ax / "config.json").read_bytes() == _cfg_bytes, "sandbox の検査後に config.json を元のバイト列へ戻した")

# (5) 凍結：初回だけ。2回目以降は照合し、変更があれば止まる
mfp = ax / "manifest.json"
keep_mf = mfp.read_text()
r = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "freeze.py"), "--write"],
                   capture_output=True, text=True, env=env)
ck(r.returncode != 0 and "再凍結しない" in r.stderr,
   "freeze --write は manifest があると拒否する（黙って再凍結しない）")
r = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "freeze.py"), "--ensure"],
                   capture_output=True, text=True, env=env)
ck(r.returncode == 0 and "照合する" in r.stdout,
   "freeze --ensure は manifest があれば照合に回る")
tgt = ax / "bin" / "lib" / "analyze.py"
orig_a = tgt.read_text()
tgt.write_text(orig_a + "\n# 改竄\n")
r = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "freeze.py"), "--ensure"],
                   capture_output=True, text=True, env=env)
ck(r.returncode != 0 and "analyze.py" in r.stderr,
   "freeze --ensure はコードが変わっていれば停止する（再凍結しない）")
tgt.write_text(orig_a)
ck(mfp.read_text() == keep_mf, "拒否された凍結で manifest が書き換わっていない")
ck("py freeze.py --ensure" in (ax / "bin" / "prepare.sh").read_text(),
   "prepare.sh が --ensure を使っている")

# (4) 費用集計：B 生成費を二重計上しない
detail = subprocess.run([sys.executable, str(ax / "bin" / "lib" / "sum_cost.py"),
                         str(ax), "--detail"], capture_output=True, text=True, env=env)
total = float(subprocess.run([sys.executable, str(ax / "bin" / "lib" / "sum_cost.py"),
                              str(ax), "--total"], capture_output=True, text=True,
                             env=env).stdout.strip())
sys.path.insert(0, str(ax / "bin" / "lib"))
import sum_cost  # noqa: E402
parts = sum_cost.breakdown(str(ax))
answers = parts["回答 run（B は生成費込み）"]
gen_only = parts["B 生成のみ（回答前）"]
gen_sum = sum(json.loads(p.read_text()).get("gen_cost_usd") or 0
              for p in (ax / "gen").glob("*.json"))
naive = sum(json.loads(p.read_text()).get("total_cost_usd") or 0
            for p in (ax / "outputs").glob("*.json")) + gen_sum
ck(gen_sum > 0, "fixture に B 生成費が入っている（この検査が意味を持つ前提）")
ck(gen_only == 0,
   f"回答 run が揃っている B の生成費を重ねて足さない（B 生成のみ={gen_only:.3f}）")
ck(abs(answers + gen_sum - naive) < 1e-6,
   f"素朴な合算との差がちょうど B 生成費ぶん（{naive - answers:.3f} / gen={gen_sum:.3f}）")
ck(total >= answers, f"合計に judge・プローブ分が含まれる（total={total:.3f} ≥ 回答={answers:.3f}）")
ck("総額の保証ではない" in detail.stdout, "費用の説明が『総額の保証ではない』と明記している")
ck("取得できない費用" in detail.stdout, "取得できない費用の欄がある")
allsh = (ax / "bin" / "all.sh").read_text()
ck("総額を保証する上限ではない" in allsh, "all.sh が MAX_USD を上限と説明していない")

print("-- 凍結 --")
mf = json.loads((ax / "manifest.json").read_text())["freezes"][-1]["hashes"]
for k in ("bin/lib/analyze.py", "bin/analyze.sh", "bin/grade2-codex.sh",
          "bin/lib/judge2_codex.py", "bin/lib/judge_prompt_context_codex.txt",
          "bin/lib/judge_schema.json", "bin/lib/check_b_prompt.py"):
    ck(k in mf, f"凍結対象に {k} が入っている")
p = ax / "bin" / "lib" / "analyze.py"
orig = p.read_text()
p.write_text(orig + "\n# 改竄\n")
rc = sh("analyze.sh")
ck(rc.returncode != 0 and "analyze.py" in rc.stderr,
   "集計コードの書き換えを analyze.sh が拒否する")
p.write_text(orig)

print("-- 人間確認（盲検 X/Y）を投入して確定させる --")
(ax / "human").mkdir(exist_ok=True)


def label_for(unit, arm):
    order = plan["blind_map"][unit]
    return "X" if order[0] == arm else "Y"


import re
needed = [m.group(1) for m in
          (re.match(r"^## (\S+_r\d+)$", ln) for ln in review.splitlines()) if m]
ck(len(needed) == 4, f"確認対象が4件（f02×2・f04×2。実際 {len(needed)}）")
for u in needed:
    arm = "B" if u.startswith("f02") else "A"   # f04 は人間が A 側を選ぶ＝反転を作る
    (ax / "human" / f"{u}.json").write_text(json.dumps(
        {"winner": label_for(u, arm), "note": "fixture", "critical_error": "none"},
        ensure_ascii=False), encoding="utf-8")
rc = sh("analyze.sh")
ck(rc.returncode == 0, "人間確認投入後に analyze.sh が通る")
report2 = (ax / "REPORT.md").read_text()
ck("**状態：完了**" in report2, "全確認が揃うと完了状態になる")
ck("| f02 | B / B | **B** |" in report2, "人間確認で f02 が B に確定する")
ck("| f04 | A / A | **A** |" in report2, "人間確認で f04 が A に確定する")
ck("B勝ち 3 ／ A勝ち 1" in report2,
   "確定後の数え上げ（f01・f02・f03 が B、f04 が A）")

print("-- 停止規則 --")
ck("2. B勝ち数が A勝ち数以下 | — " in report2, "規則2は B 3 / A 1 で外れる")
ck("1. B勝ちタスク数が3件未満 | — " in report2, "規則1は B勝ち3件で外れる")
ck("4. judge 間の食い違い率が 1/3 超（→ 判定不能） | **該当**" in report2,
   "規則4が judge 間の食い違い（8単位中4件＝50%）で発火する")
ck("判定：**判定不能（judge が信頼できない）**" in report2,
   "規則4のときは『価値信号なし』ではなく『判定不能』と書く")
ck("### 判定：**価値信号なし**" not in report2,
   "規則4該当時に価値信号なしと書かない")

print("-- 腕（A/B）で書いた人間確認を弾くか --")
(ax / "human" / "f02_r1.json").write_text(json.dumps(
    {"winner": "B", "note": "腕を直接書いた"}, ensure_ascii=False), encoding="utf-8")
rc = sh("analyze.sh")
ck("盲検が破れている" in rc.stderr, "A/B で書かれた人間確認をエラーで弾く")
ck("**状態：INCOMPLETE" in (ax / "REPORT.md").read_text(),
   "記法エラーがあると完了扱いにしない")

print()
if fail:
    print(f"配管テスト: {len(fail)} 件 失敗")
    for f in fail:
        print(f"  - {f}")
    sys.exit(1)
print("配管テスト: 全項目 合格")
PYEOF
