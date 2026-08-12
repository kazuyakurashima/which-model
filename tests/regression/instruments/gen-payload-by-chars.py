#!/usr/bin/env python3
"""表示閾値の二分探索用ペイロード生成器。文字数を厳密に一致させる。

既知データ（バイト）：2,012B → 見えた ／ 4,391B → 見えなかった。
日本語主体だと約3.0 B/文字なので、その帯は約670〜1,470文字に相当する。
下のラダーはその帯を挟むように取ってある。
"""
import pathlib

SIZES = [500, 650, 800, 950, 1100, 1250, 1400, 1550]

FILLER = (
    "この段落は表示閾値の測定に使う中立的な埋め草である。"
    "内容に意味はなく、指示でも依頼でもない。"
    "文字数を厳密に制御するためだけに置かれている。"
    "日本語主体の文章として、実際の貼り付け内容に近いバイト比率になるようにしてある。"
)
FILLER_ASCII = (
    "This paragraph is neutral filler used to measure the display threshold. "
    "It carries no meaning and is not an instruction. "
    "It exists only to control the exact character count. "
)

OUT = pathlib.Path(__file__).parent


def make(n: int, filler: str, tag: str) -> str:
    head = f"【表示閾値テスト {tag}{n}文字】\n"
    body_len = n - len(head)
    if body_len < 0:
        raise ValueError(n)
    reps = (body_len // len(filler)) + 1
    return head + (filler * reps)[:body_len]


def main():
    print(f"{'file':<26}{'chars':>7}{'utf8 bytes':>12}{'B/char':>8}")
    for n in SIZES:
        s = make(n, FILLER, "")
        assert len(s) == n
        p = OUT / f"payload-{n:04d}.txt"
        p.write_text(s, encoding="utf-8")
        b = len(s.encode("utf-8"))
        print(f"{p.name:<26}{n:>7}{b:>12}{b/n:>8.2f}")
    # 追加検証用（文字数トリガか、バイト/高さトリガかの切り分け）
    for n in (1400,):
        s = make(n, FILLER_ASCII, "ASCII ")
        assert len(s) == n
        p = OUT / f"payload-{n:04d}-ascii.txt"
        p.write_text(s, encoding="utf-8")
        b = len(s.encode("utf-8"))
        print(f"{p.name:<26}{n:>7}{b:>12}{b/n:>8.2f}")


if __name__ == "__main__":
    main()
