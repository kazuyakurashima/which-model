#!/usr/bin/env python3
"""マーカー対に挟まれた本文を抽出する（旧 .work/axis2/bin/extract.py の移植）。

使い方: extract_marker.py <file> <start-marker> <end-marker> [--stream]

`--stream` を付けると、まず parse_stream で result 本文を取り出してから探す
（stream-json のログはイベント JSON で埋まっているため、生テキストのまま
探すとエスケープされた本文に当たる）。

入力（実行ログ）にマーカー文字列がデータとして含まれうるため（回帰テストの教訓）、
**最後に出現する対**を採用する。見つからない・空のときは非ゼロ終了。
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parse_stream  # noqa: E402


def pick(text, start, end):
    s = text.rfind(start)
    if s < 0:
        return None
    e = text.rfind(end)
    if e < 0 or e <= s:
        return None
    body = text[s + len(start):e].strip()
    return body or None


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--stream"]
    use_stream = "--stream" in sys.argv[1:]
    if len(args) != 3:
        print("usage: extract_marker.py <file> <start> <end> [--stream]",
              file=sys.stderr)
        return 2
    path, start, end = args
    text = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    if use_stream:
        parsed = parse_stream.parse(text)
        if parsed["result"]:
            text = parsed["result"]
    body = pick(text, start, end)
    if body is None:
        return 1
    print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
