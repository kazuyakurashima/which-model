#!/usr/bin/env python3
"""共通のパス解決・設定読み込み。標準ライブラリのみ。"""
import json
import os
import pathlib

AX = pathlib.Path(os.environ.get("AXROOT") or
                  pathlib.Path(__file__).resolve().parents[2])


def config():
    return json.loads((AX / "config.json").read_text(encoding="utf-8"))


def tasks():
    data = json.loads((AX / "tasks.json").read_text(encoding="utf-8"))
    return [t for t in data["tasks"] if not t["id"].startswith("_")]


def task_by_id():
    return {t["id"]: t for t in tasks()}


def sandbox():
    """空の作業ディレクトリ。config.json の sandbox_dir があればそれを使う。

    **親をさかのぼって CLAUDE.md が見つかる場所は使わない。** Claude Code は作業ディレクトリの
    親の CLAUDE.md を読み、自動メモリもリポジトリ単位で読む。2026-09-14 まで sandbox は
    which-model リポジトリの内側にあり、開発規約と実験を記したメモリが文脈に入っていた。
    """
    d = None
    try:
        d = config().get("sandbox_dir")
    except (OSError, ValueError):
        d = None
    p = pathlib.Path(d) if d else AX / "sandbox"
    p.mkdir(parents=True, exist_ok=True)
    for parent in [p, *p.resolve().parents]:
        for name in ("CLAUDE.md", "CLAUDE.local.md"):
            if (parent / name).exists():
                raise SystemExit(
                    f"ERROR: sandbox の親に {parent / name} がある。"
                    "この場所で動くセッションはその指示を読むので、空の作業ディレクトリにならない。"
                    "config.json の sandbox_dir を CLAUDE.md の無い場所へ移すこと")
    return p


def resolve_workdir(task):
    """タスクの workdir を絶対パスへ。'sandbox' は実験用の空ディレクトリ。"""
    w = task["workdir"]
    return sandbox() if w == "sandbox" else pathlib.Path(w)


def unit_id(task_id, rep):
    """比較単位（タスク×反復）の識別子。"""
    return f"{task_id}_r{rep}"


def ensure_dirs():
    for d in ("prompts/A", "prompts/B", "gen", "outputs", "judgements",
              "logs", "human", "sandbox"):
        (AX / d).mkdir(parents=True, exist_ok=True)
