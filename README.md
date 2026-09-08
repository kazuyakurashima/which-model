<div align="center">

# which-model

**やりたいことを Claude に伝えると、次の2つを提案する Claude Code 用 skill。**

</div>

**①** タスクと目的に合うモデルと effort を“理由つき”で<br>
**②** そのモデルに最適化したプロンプト

<div align="center">

候補を選んで止まる——切替も実行も、**常にあなたの手に**。

**[すぐ試す](#クイックスタート)** ・ [これは何をするか](#これは何をするか) ・ [仕組み](#仕組み料理人とレシピ本)

</div>

![which-model のヒーロー画像。「Claude Code skill · model & prompt advisor」のバッジ、タイトル which-model、「Choose the right Claude for your task and priorities.」、「タスクと目的に合う Claude モデルとプロンプトを提案する Claude Code スキル。」、Select → Generate → Execute の3ステップ、そして「Claude Code の入力欄で実行」ラベルの付いたインストールコマンド（/plugin marketplace add kazuyakurashima/which-model、/plugin install which-model@kazuyakurashima、/reload-plugins）が並んでいる](docs/images/hero-overview.png)

<div align="center">

※ Anthropic 非公式の個人プロジェクト。自動切替はしません（[詳細](#免責非公式について)）。

</div>

<details>
<summary><b>動作例（デモ）を見る</b> — 実際の流れ（クリックで展開）</summary>

「ログインの仕組みを、壊れないように少しずつ確認しながら全部作り直したい」と依頼した場合の流れです。

**1. 依頼する（`/which-model:pick` に、やりたいことを普段どおり書くだけ）**

![/which-model:pick に「ログインの仕組みを壊れないように少しずつ確認しながら全部作り直したい」と入力している様子](docs/images/demo-1-input.png)

**2. フェーズ1：通常推奨と、条件を満たしたプロファイルの候補が選択UIで表示される**

![選択UI「Model」。上部に依頼「/which-model:pick ログインの仕組みを、壊れないように少しずつ確認しながら全部作り直したい」と「Ran 5 shell commands」。質問文は「どのモデルで最適化しますか？」、続けて「成果優先は条件つきの候補です（通常の設定では品質要件を満たせず、能力の余力を最大化する必要があると事前に分かっている場合）。条件を満たすと分かっている場合だけ指定してください。」「判断材料：Last verified 2026-09-02（モデルの仕様・価格は陳腐化する。古ければ更新を）」「選択後に最適化プロンプトが表示されない場合は、次のメッセージで半角の p を送ってください。」「提示した候補以外のモデルも指定できます。その場合は推奨ではなく、あなたの指定として扱います。」。選択肢は 1. 通常推奨: Fable 5.1 / high（一度に収まらない大きな移行を任せるのに向くモデルです）、2. 効率優先: Opus 5 / xhigh（段階を刻んで進めたいとき。テストや受入基準で各段階を確認できる場合。単価は下がりますが、手戻りが増えると総コストは逆転しえます）、3. 中止（何もせず終了する）、4. Type something.（自由入力）、5. Chat about this。成果優先は条件を判定できないため選択肢に出ていない。最下部に「Enter to select · ↑/↓ to navigate · Esc to cancel」](docs/images/demo-2-phase1.png)

**3. モデルを選ぶと、フェーズ2：確定モデル向けに最適化したプロンプトが表示される（まだ実行はしない）**

![「── which-model: 最適化プロンプト ──」の表示。確定モデル：Fable 5.1 / effort=high。上部には選択UIで答えた内容（「→ 通常推奨: Fable 5.1 / high」）が畳まれて残っている。最適化後プロンプトは Fixed instruction / Variables / Output format の3節からなり、影響範囲調査→計画→実装の順序、実装を小さな段階に分けて各段階ごとに動作確認とテストの合否を確認してから次へ進むこと、テストが無い箇所は先に現在の挙動を固定するテストを追加すること、指定範囲外は変更しないこと、不明点は着手前に質問することが含まれる。Variables は target・scope_in・scope_out・success_criteria、Output format は影響範囲サマリ・実行計画・段階ごとの差分・段階ごとのテスト結果の4項目。続く「主な調整点」に、Fable 5.1 の大規模リファクタ／移行テンプレートに沿って再構成し、「壊れないように少しずつ確認しながら」を段階分割・各段階の合否基準・スコープ外の明示として具体化したこと、単発の対話実行なので検証サブエージェント節を付けなかったことが書かれている。最下部の案内は「内容を確認してください」「必要なら /model で Fable 5.1 を選び、/effort high を設定してください。すでに同じ設定なら不要です（effort はセッションをまたいで残ります）。エイリアス（/model fable 等）で代用しない：接続経路によっては別世代のモデルに解決することがあるため、一覧から選び、実行前に現在のモデルを確認してください。設定を忘れて g を送ると、現在のモデル・effort のまま実行されます」「p：この表示をもう一度出す（実行しません）」「g：現在のモデル・effort で実行（一度だけ有効）」](docs/images/demo-3-phase2.png)

*（上は冒頭のみ。実際は各モデルガイドの再利用テンプレートの全文が続きます。テンプレートの構成は
モデルごとに異なります — 例えば Opus 5 向けには `Verification` 節を付けません〈自己検証が既定挙動で、
明示すると過剰検証になるため〉。上の例は Fable 5.1 が確定モデルですが、数時間規模の自律実行ではなく
単発の対話実行と判断されたため、検証サブエージェント節は付いていません。）*

このあと、実行前に `/model` の一覧から Fable 5.1 を選び、`/effort high` を設定して、**モデルと
effort の両方**をそろえたうえで（すでに同じ設定なら不要）、**`g` を送る**ことで初めて実行されます。
`/model fable` のようなエイリアスで代用しないでください — 接続経路によっては別世代のモデルに
解決します。
ポイントは **「選択 → （必要なら）設定 → `g` で実行」の一拍**。skill は**この応答では表示して
停止する**ところまでしか行わず、実行に進むのは次のターンで `g` を受け取ったときだけです
（`SKILL.md` の絶対規則によるもので、技術的に実行できないわけではありません）。

> **6.0.0 から合図が2つに分かれました。** `p`（prompt）は「最適化プロンプトを表示・再表示する」
> 合図で、**何度送っても実行しません**。実行は `g`（go）で、**一度だけ有効**です。旧 `y` は
> 使えません（モデル確定後またはプロンプト保留中に送ると `p`／`g` の案内が返ります）。理由は後述の
> [設計上の割り切り](#設計上の割り切り既知の制約)にあります。

</details>

## クイックスタート

> **Claude Code 用のプラグインです。** 以下は Claude Code CLI での導入手順です。Codex・ChatGPT・
> 通常の Claude Chat で呼び出すものではありません。**Claude Desktop の Code タブ**もプラグインに
> 対応しており、設定済みの marketplace にあるプラグインは、`+` ボタンのプラグインブラウザから導入できます。
> 以下の CLI 手順では、プラグイン機構を使うため、Claude Code の比較的新しい版が必要です（`/plugin` が使えること）。

> **Claude Code をまだ入れていない方へ。** 先に[公式のインストール手順](https://code.claude.com/docs/en/setup)で導入してください。
> **Native Install（推奨）なら Node.js は不要**です（npm 経由で入れるときだけ Node.js 22+ が要ります）。
> 例：**Windows は PowerShell** で `irm https://claude.ai/install.ps1 | iex`、**macOS / Linux** は
> `curl -fsSL https://claude.ai/install.sh | bash`。これらの導入コマンドだけは PowerShell やターミナルで実行します。
> インストール方法は変更されることがあるため、最新情報は公式手順を優先してください。

導入できたら、使いたいプロジェクトのフォルダで `claude` を実行して Claude Code を起動します
（この `claude` だけはターミナル／PowerShell で打ちます）。

```sh
claude
```

Claude Code が開いたら、次の3ステップを **ターミナルではなく Claude Code の入力欄**に打ち込みます
（すべて `/` で始まるスラッシュコマンドです。ターミナルでの clone は不要です）。

```text
/plugin marketplace add kazuyakurashima/which-model
/plugin install which-model@kazuyakurashima
/reload-plugins
```

あとは Claude Code の入力欄に `/which-model:pick <やりたいこと>` と打つだけです。

```text
/which-model:pick 認証まわりを大規模リファクタして
```

<details>
<summary>うまくいかないとき・スコープ・更新について（詳しく）</summary>

**`Unknown command: /which-model:pick` と出る**

プラグインは**セッション開始時に読み込まれます**。インストールしただけでは、いま動いている
セッションには反映されません。`/reload-plugins` を実行してください。それでも認識されない場合は、
**新しいセッションを開くか、Claude Code を再起動**してください。

**PowerShell やターミナルで `/plugin ... is not recognized` と出る（`/plugin` が動かない）**

Claude Code の**外**（PowerShell・ターミナル）で実行しています。スラッシュコマンドは Claude Code の
入力欄に打つものです。まず `claude` を実行して Claude Code を起動し、その中で打ち直してください。

**`claude is not recognized` / `command not found` と出る**

Claude Code の導入、または PATH の反映が完了していません。ターミナルを開き直して `claude --version` で
インストールを確認してください（未導入なら上の「まだ入れていない方へ」を参照）。

**インストールスコープ**

`/plugin install` の際にスコープを選べます。**特に理由がなければ User スコープ（既定）**を選んで
ください。全プロジェクトで使えるようになります。Project スコープはそのリポジトリの共同作業者
全員に、Local スコープは自分のそのリポジトリだけに入ります。

**更新の受け取り方**

このマーケットプレイスは Anthropic 公式ではない（＝サードパーティの）ため、**自動更新は既定で
オフ**です。更新は次のどちらかで受け取ります。

- **手動**：次の3行を順に実行します。カタログの更新（1行目）とプラグイン本体の更新（2行目）は
  別の操作なので、1行目だけでは新しいバージョンは入りません。

  ```text
  /plugin marketplace update kazuyakurashima
  /plugin update which-model@kazuyakurashima
  /reload-plugins
  ```

- **自動**：`/plugin` → **Marketplaces** タブ → `kazuyakurashima` を選択 → **Enable auto-update**

自動更新が入ると `/reload-plugins` を促す通知が出ます（または次回起動時に反映されます）。

**アンインストール**（Claude Code の入力欄で）

```text
/plugin uninstall which-model@kazuyakurashima
/plugin marketplace remove kazuyakurashima
```

</details>

<details>
<summary>v3.9.0（旧 standalone 版）を使っていた方へ — 移行の手順（新規の方は読み飛ばしてください）</summary>

**順序が大事です。先に旧版を消すと、新旧どちらも使えない空白ができます。**

1. **先にプラグインを入れる**（上のクイックスタートのとおり）
2. `/reload-plugins`（効かなければ新しいセッションを開く／再起動）
3. **`/which-model:pick <やりたいこと>` が動くことを確認する**
4. **動作を確認できてから**、旧版を退避する（いきなり削除せず、まず移動を推奨）

```sh
mv ~/.claude/skills/which-model ~/.claude/which-model-standalone-v3.9.0.bak
```

**変わること**

- **呼び出し名**：`/which-model` → **`/which-model:pick`**。旧版を退避すると `/which-model` は
  使えなくなります。
- **判断材料の場所**：プラグインに同梱されたものだけを読みます。**プロジェクト側の
  `docs/ai-model-guides/` は読まれません**。
  - 旧版を併用し続ける場合は、旧版がそれを読むので**消さないでください**。
  - プラグインだけを使うなら、プロジェクト側のコピーは不要です（残っていても無視されます）。

**旧 standalone 版に戻したいとき**

```sh
mv ~/.claude/which-model-standalone-v3.9.0.bak ~/.claude/skills/which-model
```

リポジトリから入れ直す場合は `git checkout v3.9.0` を使ってください（`main` の `install.sh` は
4.0.0 では何もインストールしません）。

</details>

## 目次

上の**概要図 → 動作例 → クイックスタート**が最重要の3つです。もっと知りたいときは、以下から必要な項目へ。

- [これは何をするか](#これは何をするか)
- [仕組み（料理人とレシピ本）](#仕組み料理人とレシピ本)
- [セットアップ（詳細）](#セットアップ詳細)
- [使い方とコツ](#使い方とコツ)
- [設計上の割り切り（既知の制約）](#設計上の割り切り既知の制約)
- [カスタマイズについて](#カスタマイズについて)
- [保守終了の方針](#保守終了の方針)
- [付録：CLAUDE.md 追記スニペット](#付録claudemd-追記スニペット任意本運用では非推奨)
- [ライセンス](#ライセンス)
- [免責・非公式について](#免責非公式について)

## これは何をするか

Claude Code で開発していると、指示のたびに「どのモデルを使うか」「プロンプトをそのモデル向けに
どう書くか」で迷い、選定を誤ると手戻りが起きます。この skill は、その2つを半自動化します。

1. あなたが `/which-model:pick <指示>` と入力する
2. skill が指示内容（設計・実装・リファクタ等）を判断表の16行のどれかに当てはめ、
   **目的別の3つの候補**を理由つきで選択UIに出す（**この時点ではまだモデルを切り替えない**）
   - **通常推奨** … 成果・コスト・待ち時間・扱いやすさを総合した開始点
   - **成果優先** … コストと待ち時間を評価から外したときの候補
   - **効率優先** … 必要品質を保てる根拠がある範囲で、総コストと所要時間を抑えた候補
   - 成果優先・効率優先は、**通常推奨と違う候補になる根拠が判断表にある行だけ**出ます。
     同じでよい根拠がある行は「変わりません」と表示し、**どちらとも言えない行は候補を出しません**
     （裏付けのない候補を推測で作らない設計です）。条件つきの候補は条件を添えて出ます
3. モデルを選ぶと、skill は今動いているモデルのまま、選ばれたモデル向けに最適化したプロンプトを
   生成し表示して**いったん停止する**
   - 長い依頼を貼り付けた場合だけ、選択後に `p` を送ると表示されます（理由は
     [設計上の割り切り](#設計上の割り切り既知の制約)）
4. ここで `/model` と `/effort` を確定どおりに設定する（すでに同じ設定なら不要。effort は
   セッションをまたいで残るため、前回の設定が残っていないかも確認）
5. 中身を確認し、よければ **`g` を送る**と実行される。直したいときはプロンプトを編集して送る

この「選択 → 設定 → `g` で実行」の一拍が暴走を防ぎます。モデル切替を実行直前の1回だけに
しているのは、切替先モデル（特に長時間実行向けの Fable 5.1）をプロンプト整形という軽作業のためだけに
使わないため。プロンプト最適化は常に、今起動している（切替前の）モデルが行います。

## 仕組み（料理人とレシピ本）

### 概要

**料理にたとえると分かりやすい**です。この skill は「**料理人**」と「**レシピ本**」の2つでできている、
と考えてください。

- **料理人（`skills/pick/SKILL.md`）** … 動作の段取りだけを書いた、Claude への指示書。
- **レシピ本（`references/ai-model-guides/`）** … どのモデルをどう使うかの判断材料。

料理人は判断材料を自分では持たず、レシピ本を読んで「このタスクはどのモデル・どの effort を使うか」を
判断します。判断材料を skill 本体から切り離しているので、**モデルの世代交代にはレシピ本を差し替える
だけで追従できます**。

料理人もレシピ本もプラグインに同梱されているので、インストールすれば両方そろいます。あなたの
プロジェクトに置くものはありません。

### 詳細

<details>
<summary>レシピ本の中身（6ファイル）・タグの意味・補足を開く</summary>

レシピ本（同梱の `references/ai-model-guides/`。このリポジトリでは `docs/ai-model-guides/` が正本）は6ファイル構成です。

| ファイル | 役割 |
| --- | --- |
| `00_index.md` | 全体の使い方・読み込みルール |
| `01_sources_evidence.md` | 根拠台帳（公式主張を source_id で管理） |
| `02_model_selection_matrix.md` | タスク別のモデル/effort 判断表（SKILL.md が毎回読む中核） |
| `03_fable51_prompting.md` | Fable 5.1 向けプロンプト最適化ガイド |
| `04_opus5_prompting.md` | Opus 5 向けプロンプト最適化ガイド |
| `05_sonnet5_prompting.md` | Sonnet 5 向けプロンプト最適化ガイド |

各ガイドの記述には2種類のタグが付いています。`[Official]` は Anthropic 公式ドキュメントで
裏付けられた事実（`01` の source_id に対応）、`[Heuristic]` は配布元の運用仮説（公式の裏付けなし、
Confidence 付き）です。使う人は `[Heuristic]` を自分の使い方に合わせて書き換えてください。

> このリポジトリの `README.md` は人間向けの説明書で、Claude Code は読み込みません（トークンを
> 消費しません）。Claude への動作指示は `plugins/which-model/skills/pick/SKILL.md` に、判断材料は同梱の
> `plugins/which-model/skills/pick/references/ai-model-guides/` にあります（このリポジトリの `docs/ai-model-guides/` が正本で、
> `./tools/sync-bundled-guides.sh` で同梱コピーへ同期します）。
> なお `tools/CODEX_VERIFICATION_PROMPT.md` は配布物ではない開発用ファイル（知識ベースの独立監査用
> プロンプト）で、各プロジェクトへはコピーしません。

</details>

## セットアップ（詳細）

[クイックスタート](#クイックスタート)の3行で完了します。ここでは補足だけ書きます。

### 何がどこに入るか

プラグインとして、次の2つが**一緒に**入ります。プロジェクト側に置くものはありません。
パスはプラグインルート基準です（このリポジトリでは `plugins/which-model/` 配下にあたります）。

- **料理人（`skills/pick/SKILL.md`）** … Claude への動作指示
- **レシピ本（`skills/pick/references/ai-model-guides/`）** … モデル選定の判断材料（6ファイル）

実体は Claude Code が管理する場所に置かれます。手で配置する必要はありません。

### Windows

`/plugin` コマンドは Claude Code の中で実行するので、**OS を問わず同じ手順**です（4.0.0 では
`install.sh` を使いません）。

### 動かないとき

- `/plugin` が無い → Claude Code が古い可能性があります。更新してください。
- `Unknown command: /which-model:pick` → `/reload-plugins`、それでもだめなら新しいセッションを
  開くか再起動してください（プラグインはセッション開始時に読み込まれます）。
- `/plugin marketplace add` が失敗する → リポジトリ名（`kazuyakurashima/which-model`）を確認して
  ください。

## 使い方とコツ

迷ったとき・重要な設計や大規模作業のときだけ、明示的に呼びます。普段の軽い作業では呼ばず、
設定済みのモデルでそのまま指示すれば十分です。

```
/which-model:pick 複数ユーザー対応のタスク管理アプリを設計して
```

選択UIが出たら、モデルはまだ切り替えずに候補を選びます（通常推奨／成果優先／効率優先／中止。
根拠のある候補だけが出るので、行によっては通常推奨と中止の2つだけです）。すると今の
モデルのまま最適化されたプロンプトが表示されて停止するので、`/model` で確定モデル（例：Fable 5.1）を選び、
`/effort high` のように effort も確定どおりに設定し（同じ設定なら不要）、中身を確認して
**`g` を送れば**実行されます。

> **`/model fable` と打つ近道は、環境によっては別のモデルを選びます。** Claude apps gateway 経由の
> セッションでは `fable` / `best` エイリアスが当面 **Fable 5**（5.1 ではない）に解決します（公式
> changelog 2.1.257）。**`/model` の一覧から Fable 5.1 を選び、実行前に実際の使用モデルを確認して
> ください。** なお Fable 5.1 自体が Claude Code v2.1.255 以降を必要とします。
>
> **一覧に Fable 5.1 が無い場合があります。** 公式 changelog は同じ箇所で「**Fable 5.1 に未対応の
> gateway はこれを拒否する**」と述べています。また、Claude Max サブスクリプション（gateway 経由）・
> Claude Code 2.1.263 の環境で、`/model` の一覧に Fable 5.1 が現れないことを実測しました
> （2026-09-08）。**バージョン要件を満たしていても一覧に出ないことがあります**（この 1 回の観測から
> 原因を特定はしていません）。そのときは次のどちらかにしてください。
>
> - **Fable 5 を使う**（`/model claude-fable-5`）。5.1 は 5 を拡張したもので入出力価格も同じなので、
>   同じ行での最も近い代替です。ただし**能力差は高い effort ほど大きい**とされています。
> - **Anthropic API 直結の経路に切り替える**（gateway を経由しない）。
>
> **gateway 側の対応状況は時期で変わります。** 上の実測は 2026-09-08 の 1 経路の観測なので、
> 選べない状態が続くとは限りません。`/model` の一覧を都度見てください。

長い依頼（貼り付けたログや仕様書など）を渡した場合だけ、選択後に画面が止まったように見えます。
選択UIにその旨と「`p` を送ってください」という案内が出るので、そのとおりに `p` を送ればプロンプトが
表示されます。**`p` は表示・再表示専用で、実行はしません。**

呼び方のコツ：

- **必ず行頭に `/which-model:pick` を付けて呼ぶ。** うしろは、やりたいことを普段どおり書くだけでよい
  （例：`/which-model:pick 認証まわりを大規模リファクタして`）。「リファクタして」のような実行命令の
  ままでよく、skill が起動していれば（`g` を送るまでは）実行せず「推奨モデル＋最適化プロンプト」を返して止まります
  （止まるのは SKILL.md の絶対規則によるものです。技術的に実行できないわけではありません）。
- **提案が出ず、いきなり作業（ファイル編集など）が始まったら、skill が起動していないサイン。**
  一度止めて、`/which-model:pick …` を行頭から打ち直します。
- **自然文では起動しません。** 4.0.0 では明示的に呼んだときだけ動く設計にしています
  （`disable-model-invocation`）。「どのモデルがいい？」と書いても Claude が勝手に判定を挟むことは
  ありません。必ず `/which-model:pick` から始めてください。
- **通常は、一度呼べば同じセッション内の後続の依頼にも指示が引き継がれます。** 2回目以降で毎回
  コマンドを打ち直す必要はありません（新しい依頼を書けば、フェーズ1からやり直します）。判定が
  始まらないときは、もう一度 `/which-model:pick` を付けて呼んでください。

なお **CLAUDE.md には登録しないことを推奨**します。登録すると毎回自動で判定が走り、日々の開発
テンポを損なうためです（それでも常時参照させたい場合のスニペットは[付録](#付録claudemd-追記スニペット任意本運用では非推奨)を参照）。

## 設計上の割り切り（既知の制約）

現状の Claude Code の仕様と、この skill の設計上、以下を理解した上で使ってください。

- **モデル・effort の自動切替はできない**。`/model`・`/effort` の設定はユーザーが手動で行います
  （skill が行えるのは候補の提示とプロンプトの最適化、そして `g` を受けての実行までです）（2026-07 時点の Claude Code の仕様。公式ドキュメントの明文根拠は未確認）。
  effort は `low`〜`xhigh` がセッションをまたいで保存されるため、前回の設定が残っている点にも注意
  （根拠は `01_sources_evidence.md` の S77）。
- **現在のモデルを skill 側から知る手段がない**ため、モデル不一致の自動警告はできません。
- **候補の提示は必ずポップアップ（AskUserQuestion）で行います**（6.0.0 で変更）。5.1.0 までは
  「ポップアップが出ると入力欄が塞がれ、モデル切替ができなくなる」という理由でテキスト提示に
  していましたが、この懸念は解消しました。ポップアップはモデルを選ぶだけで閉じ、`/model` の設定は
  そのあと（プロンプト表示後）に行うためです。変更した理由は次項です。
- **長い依頼を貼り付けると、VS Code 拡張のチャットで応答が画面に出ないことがあります**（拡張側の
  不具合。この skill では回避しています）。実測で原因を特定しました：**貼り付けたブロックの描画高さが
  チャット画面に収まらないと、その直後の応答が描画されません**。文字数やバイト数ではなく高さが
  引き金で、同じ 2,500 文字でも 1 段落なら表示され、160 行に割ると消えます。同じ内容でウィンドウの
  高さだけを半分にしても消えます。生成も保存も正常に終わっており、スクロールしても会話を開き直しても
  戻りません。確認できた復帰方法は、短いメッセージを新しく送ることだけでした。
  対話ターミナルでは再現しませんでした（9,621 文字で表示を確認）。近い上流報告は
  [anthropics/claude-code#61675](https://github.com/anthropics/claude-code/issues/61675)。

  **この skill の対策**：候補の提示はポップアップで行います（メッセージ一覧とは別の描画経路を
  通るため、実測した条件では長い依頼の直後でも表示されました）。そのうえで、推定表示行数が 32 行を超える入力では、
  選択後に最適化プロンプトを同じ応答で作らず、`p` を待ちます。`p` は新しい短いメッセージなので、実測した条件では描画されました。閾値を外しても壊れないよう、**ポップアップには常に「表示されない場合は `p` を
  送ってください」と書いてあります**。
- **合図は `p`（表示）と `g`（実行）の2つです**（6.0.0 の破壊的変更）。5.1.0 までは `y` が実行の
  合図でしたが、上の不具合と組み合わさると危険でした。プロンプトが生成されたのに画面に出ていない
  状態で、利用者が「見せて」のつもりで `y` を送ると、skill は「もう表示した」と認識しているため
  **一度も読まれていないプロンプトで実行に進んでしまいます**。これを塞ぐため、表示（`p`＝prompt）と
  実行（`g`＝go）を別のキーに分け、**「はい」を連想させる `y` にはどちらも割り当てませんでした**
  （モデル確定後またはプロンプト保留中に `y` を送ると、`p`／`g` の案内が返るだけです）。**`g` は一度だけ有効**で、受理した時点で実行権を
  消費します。同一セッションで状態が保持されている通常経路では、実行の途中で失敗・中断しても
  `g` の再送で再実行しないよう設計しています（二重実行の防止。会話の圧縮・再開などで状態が
  失われた場合まで厳密に保証するものではありません。再試行は新しい依頼として送ってください）。skill は現在のモデル・effort を確認できないため、
  **設定を忘れて `g` を送ると現在の設定のまま実行されます**。プロンプトを編集して送る経路も
  使えます。
- **提示するのは、判断表に根拠が書かれている候補だけです。** 7.0.0 で候補を目的別
  （通常推奨・成果優先・効率優先）へ整理しました。6.0.0 までの「第一候補・第二候補」は
  廃止しています。**差を裏付ける評価が無い組み合わせには候補を出さず、その旨を表示します。**
  したがって「コスト度外視なら」「安く済ませるなら」と聞いても、根拠の無い行では候補は増えません。
  **これは機能不足ではなく、裏付けのない推奨を出さないための意図的な挙動です**（16行×2プロファイル
  ＝32通りのうち、9通りは「根拠なし」と記録してあります）。
  条件つきの候補（例：自前のレビュー評価が済んでいる場合だけ effort を下げる）は、**条件を判定
  できないときも候補にしません**。条件を提示するので、満たすと分かっている場合だけ指定してください。
- **skill は読み取り専用ではありません**。`allowed-tools: Read` は Read を事前許可する設定で、
  他のツールを禁止するものではありません。`g` を受け取るまで提示で止まるのは SKILL.md の絶対規則に
  従っているためであって、技術的な制約ではありません。
- **判定に時間がかかることがあります**。実測では、提示まで数十秒〜2分超かかった例がありました。
  指示の文字数との単純な比例は見られず、セッションのコンテキスト量や effort も影響している
  可能性があります（未検証）。急ぐときは会話履歴の浅いセッションか、軽いモデルで呼んでください。
- **会話ログを丸ごと貼り付けると、推奨の提示を飛ばすことがあります**（既知・完全には直っていません）。
  貼り付けたログの中の `p`・`g`（旧 `y` を含む）や過去のモデル提案を、いまの会話の続きだと読み違えるためです。3.9.0 で
  大きく減らしましたが、確率的に再発します。起きたときは、依頼を短くまとめ直して呼び直してください。
  検証記録は [`tests/regression/`](tests/regression/) にあります。
- **対象は対話型の Claude Code です**（VS Code 拡張・対話ターミナルのどちらでも動きます）。
  headless（`claude -p`）では `AskUserQuestion` が使えないことがあり、その場合は候補をテキストで
  提示する経路に自動で切り替わります（確定合図は `p`／`p normal`＝通常推奨、`p quality`＝成果優先、
  `p efficiency`＝効率優先、`p model <モデル> [<effort>]`＝直接指定、`n`＝中止。
  **旧 `p opus` / `p fable` / `p sonnet` は 7.0.0 で廃止**し、送ると書き方の案内を返します。
  ここでの `p` は合図であって、CLI オプションの `claude -p` とは別物です）。単発実行では表示後の
  `g` に到達しませんが、`--resume` 等の再開経路では到達しえます。ただし **headless で複数ターンに
  またがる使い方は保証していません**（フェーズ2でガイドの読み取りが権限で止まることを確認
  しています）。
- **skill は自分がどの入口で動いているかを知れません**。VS Code 拡張か対話ターミナルかを
  判別する手段がないため（環境変数はスキル本文に展開されず、判別するとシェル実行が必要になります）、
  ターミナルでも同じ判定が働きます。ターミナルでは上記の描画不具合が起きないので、長い依頼の
  ときにポップアップと `p` が要るのは不要な手間ですが、害はありません。

## カスタマイズについて

**いまは、判断材料をプロジェクトごとに差し替えることはできません。** skill はプラグインに同梱された
レシピ本だけを読みます。

理由は、安全性と、どの環境でも同じ判断材料で動くことを優先したためです。プロジェクトごとの上書きを
許すと、クローンしてきたリポジトリに置かれたファイルを、それと知らずに判断材料として読んでしまう
余地が生まれます。現行版では、同梱された判断材料だけを読む設計にしています。

**調整したい場合**は、いまのところリポジトリを fork して、`docs/ai-model-guides/` を書き換え、
`./tools/sync-bundled-guides.sh` を実行して自分のプラグインとして使ってください。

プロジェクトごとの調整に需要があることが分かれば、**明示的なオプトイン**として再導入を検討します。
必要な方は Issue で教えてください。

### レシピ本の読み方（fork する方向け）

- `[Official]` タグの記述は公式裏付けがあります（`01_sources_evidence.md` の `source_id` が根拠）。
  モデル世代が変わるまで基本そのままで問題ありません。
- `[Heuristic]` タグの記述は配布元の経験則です。自分の使い方に合わせて書き換えてください。
- 各ファイル冒頭の `Last verified` 日付が古くなったら（目安：1〜2ヶ月）、公式ドキュメントで
  再確認してください。モデルの仕様・価格は頻繁に変わります。

## 保守終了の方針

このツールは、Claude Code に公式のモデル自動選択が実装されれば役目を終えます。そうなったときは、
黙って放置せず次の順序で終了させます。

1. README で非推奨を告知する
2. 公式機能への移行方法を掲載する
3. 最終版をリリースする
4. Marketplace への掲載終了を依頼する
5. **GitHub リポジトリは削除せず Archive する**（既存の利用者が参照できるように）

**「撤退」ではなく「非推奨化と移行案内」**と考えています。インストール済みのコピーを配布元から
強制的に消す手段はないため、静かに消えるより、古くなったことが分かる形で残す方が誠実だからです。

同じ理由で、フェーズ1の提示にはレシピ本の `Last verified` 日付を出しています。更新が止まった版を
使い続けても、判断材料が古いことに気づけるようにするためです。

## 付録：CLAUDE.md 追記スニペット（任意・本運用では非推奨）

> **⚠️ 4.0.0 では、この付録を使うにはひと手間要ります。** 下のスニペットは
> `docs/ai-model-guides/` がプロジェクトにある前提で書かれていますが、4.0.0 のレシピ本は
> プラグインに同梱されており、**あなたのプロジェクトには置かれません**。使う場合は、
> このリポジトリの `docs/ai-model-guides/` を自分のプロジェクトへ手でコピーしてください
> （skill 自体はそれを読みませんが、CLAUDE.md 経由で Claude に読ませることはできます）。

上記の通り本運用では CLAUDE.md への登録は推奨しませんが、skill を使わず常時参照させたい
場合は以下を CLAUDE.md に貼ってください。各行は `02_model_selection_matrix.md` の
記述の要約です（根拠：S6, S25, S65, S67, S68, S71, S81, S86, S91, S98, S104, S123, S125, S127, S131。
うち「速い対話・高頻度は Sonnet 5 / Fable 5.1 不使用」と「ZDR 前提の代替モデル選択」は公式事実から
導く運用判断（`[Heuristic]`）。タグ・source_id はランタイムのノイズになるため省略。裏付けは
`01_sources_evidence.md` を参照）。

```md
## Model routing & prompt optimization

When choosing which Claude model to use, or optimizing a prompt for a specific
model, consult these guides. Read only the file relevant to the current task —
do not load all of them.

- Deciding which model for a task → docs/ai-model-guides/02_model_selection_matrix.md
- Prompting Fable 5.1 (claude-fable-5-1) → docs/ai-model-guides/03_fable51_prompting.md
- Prompting Opus 5 (claude-opus-5) → docs/ai-model-guides/04_opus5_prompting.md
- Prompting Sonnet 5 (claude-sonnet-5) → docs/ai-model-guides/05_sonnet5_prompting.md

Quick defaults:
- Unsure / complex agentic coding → Opus 5 (default). Effort defaults to high; start there and
  step up to xhigh for demanding coding and agentic work (multi-file features, larger refactors,
  end-to-end work, deep dependency tracing). Official guidance for Opus 4.8/4.7 differs: xhigh
  is the recommended starting point there.
- On Opus 5, do not add redundant self-verification steps ("include a final verification step",
  "use a subagent to verify", "double-check your answer") — it self-verifies, and these cause
  over-verification. Acceptance criteria, which tests must pass, and "check against the code
  rather than assuming" are all fine.
- Fast, high-frequency, or simple → Sonnet 5 (effort=low for simple lookups). Do not use Fable 5.1 for these.
- Demanding reasoning, long-horizon agentic work, or evals still falling short on Opus 5 at higher
  effort → Fable 5.1 (start at effort=high). Set up timeouts, progress, and refusal fallback first
  (Claude Code falls back automatically; requires Claude Code v2.1.255+).
- If something goes wrong, check context first (prompt clarity, CLAUDE.md, task scope) before
  touching model/effort — the fix is often upstream, not a knob.
- Still not working? Diagnose: skipped a file / didn't run tests / didn't double-check → raise
  effort. Had all the context and clearly tried, still wrong → switch to a larger model.
- Sensitive data under ZDR → avoid Fable 5.1 and Fable 5 (Covered Models, ZDR-ineligible). Opus 4.8 and Sonnet 5
  are ZDR-eligible, but ZDR eligibility also depends on your org arrangement, the API features you
  use, and the surface (consumer plans and some features are out of scope).

All `[Official]` claims are backed by docs/ai-model-guides/01_sources_evidence.md.
```

## ライセンス

このプロジェクトは [Apache License 2.0](./LICENSE) で公開されています。無料で利用・改変・
再配布・商用利用ができます（詳細は `LICENSE` を参照）。

## 免責・非公式について

> **これは Anthropic 非公式の個人プロジェクトです。** Anthropic 社およびその公式製品とは
> 関係ありません（"Claude" は Anthropic の商標です）。掲載する各モデルの仕様・価格は
> `[Official]` タグの範囲で公式ドキュメントに基づきますが、本 skill 自体は公式のものでは
> ありません。本ライセンスは商標の使用権を付与しません（Apache-2.0 §6）。
>
> **「どのモデルか（which model）」を選ぶための skill ですが、モデルを自動で切り替えることはしません。** 現在の
> Claude Code の仕様上それはできず、また設計としても切替はユーザーの手動操作に委ねています。
> この skill がするのは「どのモデルを使うかの提示」と「そのモデル向けプロンプトの最適化」で、
> `/model`・`/effort` の設定はあなたが行います。**実行を始めるかどうかもあなたが `g` で明示し、
> タスク本体はその後 skill が実行します**（自動では始まりません）。

---

<div align="center">

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Status](https://img.shields.io/badge/status-unofficial-lightgrey.svg)](#免責非公式について)
[![Version](https://img.shields.io/github/v/release/kazuyakurashima/which-model?label=version)](https://github.com/kazuyakurashima/which-model/releases/latest)

</div>
