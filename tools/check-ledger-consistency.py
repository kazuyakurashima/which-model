#!/usr/bin/env python3
"""レシピ本と根拠台帳の整合を機械検査する（リリース前ゲート）。

`docs/ai-model-guides/` を対象に、次を検査する：

1. **ダングリング参照**：02〜05 が引用する `S<数字>` が 01 に定義されているか。
2. **Retired 参照**：Retired 済みの source_id を引いていないか。
3. **出典欄の一致**：03〜05 の本文で使った S-id が「## 8. 出典」に列挙されているか（逆も）。
4. **対象モデルの整合**：モデル別ガイド（03/04/05）が引く S-id の「対象」欄に、そのモデルが
   含まれているか。**上流（台帳）を直したのに下流（ガイド）が追随していない、あるいはその逆を
   検出するための検査**で、5.0.0 の監査で実際に2件の抜けを捕まえた。

4 は誤検知が出うる（例：Fable 5 のガイドがフォールバック先として Opus のライフサイクル主張を
引くのは正当）。**警告として出し、人が判断する**。1〜3 は落ちたら修正する。

使い方：
    python3 tools/check-ledger-consistency.py            # 検査
    python3 tools/check-ledger-consistency.py --strict   # 4 の警告も終了コードに含める
"""

import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "docs" / "ai-model-guides"
LEDGER = BASE / "01_sources_evidence.md"
CITING = ["00_index.md", "02_model_selection_matrix.md", "03_fable5_prompting.md",
          "04_opus5_prompting.md", "05_sonnet5_prompting.md"]
MODEL_GUIDES = {"03_fable5_prompting.md": "Fable 5",
                "04_opus5_prompting.md": "Opus 5",
                "05_sonnet5_prompting.md": "Sonnet 5"}
# 「対象」欄がこれらを含む主張は、どのガイドから引いてもよい
GENERIC_TARGETS = ("全モデル", "Claude Code", "—")


def parse_ledger():
    """S-id → (対象欄, Retired か) を返す。"""
    rows = {}
    for line in LEDGER.read_text().split("\n"):
        if not line.startswith("| S"):
            continue
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 5:
            continue
        sid = cells[1]
        if not re.fullmatch(r"S\d+", sid):
            continue
        # Retired 行は主張欄が「**Retired（日付）**」で始まる。
        # 単に本文で Retired という語を説明している行（ライフサイクル用語の解説など）を
        # 誤検出しないよう、先頭一致で判定する。
        rows[sid] = (cells[3], bool(re.match(r"\*\*Retired", cells[2])))
    return rows


def cited_ids(text):
    return {f"S{n}" for n in re.findall(r"\bS(\d+)\b", text)}


def main():
    strict = "--strict" in sys.argv
    ledger = parse_ledger()
    defined = set(ledger)
    retired = {s for s, (_, r) in ledger.items() if r}
    errors, warnings = [], []

    print(f"台帳: {len(defined)} 件定義 / Retired {len(retired)} 件 "
          f"({', '.join(sorted(retired, key=lambda x: int(x[1:])))})\n")

    # 1・2：ダングリング参照と Retired 参照
    for f in CITING:
        refs = cited_ids((BASE / f).read_text())
        for sid in sorted(refs - defined, key=lambda x: int(x[1:])):
            errors.append(f"{f}: {sid} は 01 に定義がない（ダングリング参照）")
        for sid in sorted(refs & retired, key=lambda x: int(x[1:])):
            errors.append(f"{f}: {sid} は Retired。置換先の source_id を引くこと")

    # 3：出典欄の一致
    for f in MODEL_GUIDES:
        txt = (BASE / f).read_text()
        m = re.search(r"## 8\. 出典\n+(.*?)(?:\n\n|\Z)", txt, re.S)
        if not m:
            errors.append(f"{f}: 「## 8. 出典」節が見つからない")
            continue
        listed = cited_ids(m.group(1))
        used = cited_ids(txt[:m.start()])
        for sid in sorted(used - listed, key=lambda x: int(x[1:])):
            errors.append(f"{f}: 本文で {sid} を使っているが 8.出典 に未記載")
        for sid in sorted(listed - used, key=lambda x: int(x[1:])):
            errors.append(f"{f}: 8.出典 に {sid} があるが本文で未使用")

    # 4：対象モデルの整合
    for f, model in MODEL_GUIDES.items():
        txt = (BASE / f).read_text()
        m = re.search(r"## 8\. 出典\n+(.*?)(?:\n\n|\Z)", txt, re.S)
        for sid in sorted(cited_ids(m.group(1)), key=lambda x: int(x[1:])):
            tgt = ledger[sid][0]
            if any(g in tgt for g in GENERIC_TARGETS) or model in tgt:
                continue
            warnings.append(f"{f}（{model}）: {sid} の対象欄は「{tgt}」— "
                            f"{model} が含まれない。意図的な他モデル参照か確認する")

    if errors:
        print("❌ エラー")
        for e in errors:
            print(f"  - {e}")
    else:
        print("✅ ダングリング参照・Retired 参照・出典欄の一致：問題なし")

    if warnings:
        print("\n⚠️ 要確認（対象モデルの整合）")
        for w in warnings:
            print(f"  - {w}")
    else:
        print("✅ 対象モデルの整合：問題なし")

    return 1 if errors or (strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
