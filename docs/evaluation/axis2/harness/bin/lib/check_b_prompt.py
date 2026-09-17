#!/usr/bin/env python3
"""B プロンプトが狙ったモデル向けに生成されたかを検査する（DESIGN.md §2）。

使い方: check_b_prompt.py            … 全 B プロンプトを検査
        check_b_prompt.py <task> <rep> … 1 本だけ検査

B 生成は skill の縮退経路に `p model <alias> <effort>` を渡す。alias が skill 内部で
どの世代に解決するかは skill 側の実装で決まるため、**生成物に書かれた確定モデル名**を
読んで、狙った世代と一致することを確かめる。

`prompts/B/<task>_r<rep>.txt` は「最適化後プロンプト：」〜「主な調整点：」の間だけを
抽出したものなので `確定モデル：` 行を含まない。そこで**生成ログ**（logs/gen_*_phase2.log）
の本文から `確定モデル：<名前> / effort=<level>` を探す。

一致しなければ非ゼロ終了する。**取り違えたまま「5.1 で測った」と書かないため。**
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402
import parse_stream  # noqa: E402

# model_id → 確定表示に現れるべき名前（表示は日本語混じりの人間向け名）
DISPLAY = {
    "claude-fable-5-1": "Fable 5.1",
    "claude-fable-5": "Fable 5",
    "claude-opus-5": "Opus 5",
    "claude-sonnet-5": "Sonnet 5",
    "claude-haiku-4-5": "Haiku 4.5",
}
# 「Fable 5.1」を狙ったときに「Fable 5」だけが出ていたら不一致にしたいので、
# 部分一致の罠（"Fable 5" は "Fable 5.1" の接頭辞）を境界付きで避ける。
# effort は low/medium/high/xhigh/max の英字のみ。`(\S+)` にすると、直後に空白なしで続く
# 日本語（例「effort=medium（あなたの指定として受理しました）」）まで飲み込んで
# 偽の不一致になる（2026-09-14 に実際に発生）。
CONFIRM_RE = re.compile(r"確定モデル：\s*(.+?)\s*/\s*effort=([A-Za-z]+)")


def confirmed(task_id, rep):
    """生成ログから (確定モデル名, effort) を返す。見つからなければ None。"""
    logs = sorted((common.AX / "logs").glob(f"gen_{task_id}_r{rep}_a*_phase2.log"))
    for p in reversed(logs):          # 最後に成功した attempt を優先
        d = parse_stream.parse(p.read_text(encoding="utf-8", errors="replace"))
        body = d.get("result") or ""
        ms = CONFIRM_RE.findall(body)
        if ms:
            return ms[-1]             # 本文に複数出たら最後を採る
    return None


def check(task, rep):
    tid = task["id"]
    want_name = DISPLAY.get(task["model_id"])
    want_effort = task["target_effort"]
    got = confirmed(tid, rep)
    if want_name is None:
        return f"{tid} r{rep}: model_id {task['model_id']} の表示名が未登録"
    if got is None:
        return (f"{tid} r{rep}: 生成ログに『確定モデル：』が見つからない"
                f"（logs/gen_{tid}_r{rep}_a*_phase2.log）")
    name, effort = got
    if name.strip() != want_name:
        return (f"{tid} r{rep}: 確定モデルが狙いと違う — 期待『{want_name}』／"
                f"実際『{name.strip()}』。B プロンプトが別世代向けに書かれている")
    if effort.strip() != want_effort:
        return (f"{tid} r{rep}: effort が狙いと違う — 期待 {want_effort}／"
                f"実際 {effort.strip()}")
    return None


def main() -> int:
    tasks = common.tasks()
    reps = range(1, int(common.config()["reps"]) + 1)
    if len(sys.argv) == 3:
        by = common.task_by_id()
        pairs = [(by[sys.argv[1]], int(sys.argv[2]))]
    else:
        pairs = [(t, r) for t in tasks for r in reps]

    errs, checked, skipped = [], 0, 0
    for task, rep in pairs:
        out = common.AX / "prompts" / "B" / f"{task['id']}_r{rep}.txt"
        if not out.is_file():
            skipped += 1          # まだ生成していない分は gate.py が見る
            continue
        e = check(task, rep)
        checked += 1
        if e:
            errs.append(e)
    for e in errs:
        print(f"ERROR: {e}", file=sys.stderr)
    if errs:
        print("\nB プロンプトが狙ったモデル向けになっていない。"
              "\n該当の prompts/B/*.txt と logs/gen_* を削除して prepare.sh を再実行するか、"
              "\nエイリアスの解決先が変わったのなら tasks.json の model_id を実態へ合わせ、"
              "\nその旨を REPORT に記録すること。", file=sys.stderr)
        return 1
    print(f"B プロンプト検査: ok（{checked} 本"
          + (f"／未生成 {skipped} 本" if skipped else "") + "）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
