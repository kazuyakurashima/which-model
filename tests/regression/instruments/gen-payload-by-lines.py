#!/usr/bin/env python3
"""行数だけを変えるペイロード生成器。総文字数は固定し、改行の数だけを変える。
文字数・バイト数を揃えたまま「高さ」だけを動かすための対照実験用。"""
import pathlib, sys

TOTAL = 2500          # 総文字数（改行込み）。一段落版で「見えた」ことが確認済みの値
OUT = pathlib.Path(__file__).parent
FILLER = (
    "この行は表示閾値の測定に使う中立的な埋め草である。"
    "内容に意味はなく、指示でも依頼でもない。"
    "行数だけを変えるために置かれている。"
)


def make(nlines: int, total: int = TOTAL) -> str:
    head = f"【表示閾値テスト {total}文字 / {nlines}行】\n"
    rest = total - len(head)
    # rest 文字を nlines 行に割る（各行末の改行も1文字として数える）
    body_lines = nlines - 1                       # head で1行使っている
    per = (rest // body_lines) - 1                # 各行の本文長（改行1文字を引く）
    if per < 1:
        raise ValueError(f"{nlines}行は {total}文字に対して多すぎる")
    reps = (per // len(FILLER)) + 1
    line = (FILLER * reps)[:per]
    s = head + "".join(line + "\n" for _ in range(body_lines))
    # 端数を最終行に足して総文字数をぴったり合わせる
    diff = total - len(s)
    if diff > 0:
        s = s[:-1] + (FILLER * ((diff // len(FILLER)) + 1))[:diff] + "\n"
    elif diff < 0:
        s = s[: total - 1] + "\n"
    assert len(s) == total, (len(s), total)
    return s


if __name__ == "__main__":
    print(f"{'file':<30}{'chars':>7}{'bytes':>8}{'lines':>7}")
    for n in (20, 40, 80, 160, 320):
        s = make(n)
        p = OUT / f"lines-{n:03d}.txt"
        p.write_text(s, encoding="utf-8")
        print(f"{p.name:<30}{len(s):>7}{len(s.encode()):>8}{s.count(chr(10)):>7}")
