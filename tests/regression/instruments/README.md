# 描画閾値の計測器（保管）

[`../vscode-render-threshold.md`](../vscode-render-threshold.md) の測定に使った道具一式。
**6.0.0 の測定時にだけ使い、常用しない。** 再測定するときのために保管している。

これらは `~/.claude/skills/` に一時インストールした使い捨てスキルだった。測定が終わったので
インストール先からは削除し、実体をここに残した。**この場所に置いたままでは動かない**
（Claude Code はここを読まない。下の手順でインストールする）。

## なぜ専用の計測器が要ったか

`/which-model:pick` 自体で測ると、判定内容・応答長・所要時間が毎回変わって交絡する。
**引数を読まず固定長のテキストだけ返すスキル**にすることで、変数を「入力の見た目」だけに絞った。

## 中身

| ファイル | 役割 |
| --- | --- |
| `wm-text-test.SKILL.md` | 通常テキストの描画可否だけを測る。`AskUserQuestion` を呼ばない |
| `wm-popup-test.SKILL.md` | 選択UIの描画と、**選択後**の通常テキストの描画を測る |
| `gen-payload-by-chars.py` | 文字数を厳密に揃えたペイロードを作る（測定1用） |
| `gen-payload-by-lines.py` | **総文字数を 2,500 に固定したまま行数だけ変える**（測定2用） |

`gen-payload-by-lines.py` が要点。文字数・バイト数を揃えて行数だけを動かすので、
**「文字数が引き金」説を単独で棄却できる。**

## 使い方

```sh
# 1. スキルをインストールする（ファイル名から .SKILL を外す）
mkdir -p ~/.claude/skills/wm-text-test
cp tests/regression/instruments/wm-text-test.SKILL.md ~/.claude/skills/wm-text-test/SKILL.md

# 2. ペイロードを生成する（スクリプトと同じディレクトリに出力される）
mkdir -p /tmp/ui-threshold
cp tests/regression/instruments/gen-payload-by-*.py /tmp/ui-threshold/
python3 /tmp/ui-threshold/gen-payload-by-lines.py

# 3. 対話環境で貼って送り、目印ブロックが画面に出たかだけを記録する
#    /wm-text-test <ペイロード>
```

**1回につき新規会話で行う。** 同じ会話で続けると直前の描画状態が交絡する。

`gen-payload-by-lines.py` の既定は 20 / 40 / 80 / 160 / 320 行。実測で境界を挟んだ
50 / 60 / 70 行は、末尾のタプルを書き換えて生成した。

## 測定するときの注意

- **合否は目視で判定する。** 見えたか見えなかったかだけを記録し、ログや JSONL で判定しない
  （不可視でも応答は正常に生成・保存されるので、ログ上は成功に見える）。
- **ウィンドウの高さと表示解像度を必ず記録する。** これが真の変数なので、記録しないと
  他の測定と比較できない。
- 対話ターミナルでは再現しない。VS Code 拡張で測ること。
