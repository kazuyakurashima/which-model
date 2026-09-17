#!/usr/bin/env python3
"""生成物と設定を SHA-256 で凍結し、以後の変更を検出する（DESIGN.md §11）。

使い方:
  freeze.py --write   … 現在の内容を manifest.json へ記録する
                        **既に manifest.json があれば拒否する**（--force で上書き追記）
  freeze.py --check   … manifest.json と現在の内容を突き合わせる。差があれば非ゼロ終了
  freeze.py --ensure  … manifest.json が無ければ --write、あれば --check

`--ensure` を使うこと。prepare や all を再実行するたびに --write すると、
**結果を見てから変えたコードが黙って再凍結される**。

凍結対象は固定リスト（下の TARGETS）。**結果を見てから設計・停止規則・プロンプトを
書き換えられないようにするための仕掛け**なので、対象を実行中に増減させないこと。
"""
import argparse
import datetime
import hashlib
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402

FIXED = [
    "DESIGN.md",
    "STOP-RULES.md",
    "config.json",
    "tasks.json",
    "plan.json",
]
# **コード自体を凍結する。** 集計ロジックを凍結しないと、結果を見てから
# analyze.py を書き換えても検出できず、停止規則を事前凍結したことにならない。
GLOBS = [
    "prompts/*/*.txt",
    "gen/*.json",
    "bin/*.sh",
    "bin/lib/*.py",
    "bin/lib/*.txt",
    "bin/lib/*.json",
]


def collect(ax: pathlib.Path):
    rels = list(FIXED)
    for g in GLOBS:
        rels += sorted(str(p.relative_to(ax)) for p in ax.glob(g))
    out = {}
    for rel in rels:
        p = ax / rel
        if p.exists():
            out[rel] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def claude_version():
    try:
        return subprocess.run(["claude", "--version"], capture_output=True,
                              text=True).stdout.strip()
    except OSError:
        return "unknown"


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--write", action="store_true")
    g.add_argument("--check", action="store_true")
    g.add_argument("--ensure", action="store_true",
                   help="manifest が無ければ凍結、あれば照合（再凍結しない）")
    ap.add_argument("--force", action="store_true",
                    help="--write で既存 manifest があっても追記する")
    a = ap.parse_args()

    ax = common.AX
    mf = ax / "manifest.json"
    cur = collect(ax)

    if a.ensure:
        # 初回だけ凍結する。既にあるなら照合に回す（**再凍結しない**）。
        if mf.exists():
            print("freeze: manifest あり → 照合する（再凍結しない）")
            a.check = True
        else:
            a.write = True

    if a.write:
        if mf.exists() and not a.force:
            print("ERROR: manifest.json が既にある。**再凍結しない。**\n"
                  "  照合するなら --check、意図して作り直すなら --force を付け、"
                  "その旨を STOP-RULES.md §4 に記録すること。", file=sys.stderr)
            return 1
        data = json.loads(mf.read_text(encoding="utf-8")) if mf.exists() else {"freezes": []}
        data["freezes"].append({
            "at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
            "claude_version": claude_version(),
            "hashes": cur,
        })
        mf.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"frozen: {len(cur)} files → manifest.json")
        return 0

    if not mf.exists():
        print("ERROR: manifest.json が無い。先に bin/prepare.sh を実行すること", file=sys.stderr)
        return 1
    frozen = json.loads(mf.read_text(encoding="utf-8"))["freezes"][-1]["hashes"]
    changed = [k for k in frozen if k in cur and cur[k] != frozen[k]]
    missing = [k for k in frozen if k not in cur]
    added = [k for k in cur if k not in frozen]
    for k in changed:
        print(f"ERROR: 凍結後に変更された: {k}", file=sys.stderr)
    for k in missing:
        print(f"ERROR: 凍結後に消えた: {k}", file=sys.stderr)
    for k in added:
        print(f"ERROR: 凍結後に増えた: {k}", file=sys.stderr)
    if changed or missing or added:
        print("実行を中止する。設計・停止規則・プロンプトを凍結後に変えると"
              "確認的な試験でなくなる。意図した変更なら manifest.json を作り直し、"
              "その旨を STOP-RULES.md §4 に記録すること。", file=sys.stderr)
        return 1
    print(f"freeze check: ok（{len(cur)} files）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
