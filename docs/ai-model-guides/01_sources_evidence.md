# 01. 根拠台帳（Sources & Evidence Ledger）

このファイルは、他のすべてのファイルの `[Official]` 記述の裏付けを一元管理する。各主張には `source_id`（S1, S2, …）が振られ、公式ページと確認日に紐づく。

**ルール**
- `[Official]` タグの付いた記述は、必ずこの台帳の `source_id` に対応する。
- ここに載っていない主張を `[Official]` として書いてはいけない。
- モデルの自己認識・推測・経験則は `[Official]` に含めない（それらは各ファイルで `[Heuristic]` として書く）。

Last verified: 2026-07-05

## 公式ソース一覧

| src | ページ名 | URL |
| --- | --- | --- |
| P1 | Models overview | https://platform.claude.com/docs/en/about-claude/models/overview |
| P2 | Choosing the right model | https://platform.claude.com/docs/en/about-claude/models/choosing-a-model |
| P3 | Introducing Claude Fable 5 and Claude Mythos 5 | https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5 |
| P4 | What's new in Claude Opus 4.8 | https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8 |
| P5 | What's new in Claude Sonnet 5 | https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5 |
| P6 | Prompting best practices | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices |
| P7 | Prompting Claude Fable 5 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5 |
| P8 | Prompting Claude Opus 4.8 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8 |
| P9 | Prompting Claude Sonnet 5 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5 |
| P10 | Introducing Claude Opus 4.8 (blog) | https://www.anthropic.com/news/claude-opus-4-8 |
| P11 | Model configuration (Claude Code) | https://code.claude.com/docs/en/model-config |
| P12 | Migration guide | https://platform.claude.com/docs/en/about-claude/models/migration-guide |

## 主張台帳

### モデル選定（ポジショニング）

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S1 | 迷ったら、複雑なエージェント型コーディングとエンタープライズ作業には Opus 4.8 から始める | Opus 4.8 | P1, P2 |
| S2 | 最高能力が必要なワークロードには Fable 5 を使う | Fable 5 | P1 |
| S3 | Fable 5 は Anthropic の最も高能力な一般提供モデルで、長時間稼働エージェント向けの次世代知能を提供する | Fable 5 | P1, P2, P3 |
| S9 | Fable 5 は、人間が数時間・数日・数週間かける端から端までの作業に特に効果的。テストを簡単なワークロードだけに限ると真価を過小評価しがち | Fable 5 | P7 |
| S10 | Fable 5 は速度や量のためのものではない。素早い対話的・高頻度なタスクには不向きで、遅く高価な割に利点がない | Fable 5 | P7 |
| S11 | Sonnet 5 は Sonnet ティアで速度と知性の最良の組み合わせ。コーディング・エージェント作業で Opus に迫る品質 | Sonnet 5 | P5 |
| S12 | Sonnet 5 は Sonnet 4.6 に対する能力向上版で、同価格。最大の向上はコーディングとエージェント作業 | Sonnet 5 | P5 |

### スペック・価格

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S13 | Fable 5：入力 $10 / 出力 $50（per MTok）、1M コンテキスト（既定）、最大出力 128k | Fable 5 | P1, P3, P12 |
| S14 | Opus 4.8：入力 $5 / 出力 $25、1M コンテキスト（既定）、最大出力 128k | Opus 4.8 | P1, P12 |
| S15 | Sonnet 5：入力 $3 / 出力 $15、1M コンテキスト（既定）、最大出力 128k。2026-08-31 まで導入価格 $2/$10 | Sonnet 5 | P1, P5 |
| S16 | Fable 5 は 30 日データ保持が必須で、ZDR（ゼロデータ保持）では利用不可。Covered Model 指定。Opus 4.8 は ZDR で引き続き利用可 | Fable 5 | P3, P12 |

### effort / thinking

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S6 | effort パラメータは単一モデル内で知性と速度・コストをトレードオフする。effort の調整はモデル切り替えより良いレバーであることが多い | 全モデル | P2 |
| S7 | effort の既定は Fable 5 / Sonnet 5 / Opus 4.8 で high。Opus 4.8/4.7 では xhigh（high と max の間）がコーディング・エージェント用途に最適 | 全モデル | P2, P11 |
| S8 | Fable 5・Mythos 5 は adaptive thinking が唯一のモード。常時 on。thinking:{type:"disabled"} は非対応（Fable 5 は 400） | Fable 5 | P3, P6, P12 |
| S17 | Opus 4.8 / Sonnet 5 では manual extended thinking（budget_tokens）は削除済みで 400 エラー。adaptive thinking + effort を使う | Opus 4.8, Sonnet 5 | P4, P5 |
| S18 | Sonnet 5 は adaptive thinking が既定 on（Sonnet 4.6 は off だった）。off にするには thinking:{type:"disabled"} | Sonnet 5 | P5, P9 |

### Fable 5 固有のプロンプティング挙動

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S19 | Fable 5 では生の思考連鎖（raw CoT）は決して返らない。「思考を出力せよ」「推論を説明せよ」等の指示は reasoning_extraction 拒否カテゴリを誘発し、Opus 4.8 へのフォールバックを増やす | Fable 5 | P7, P12 |
| S20 | 推論の可視化が必要なら、thinking.display:"summarized" で要約された thinking ブロックを読む設計にする | Fable 5 | P3, P7 |
| S21 | 難易度レンジの上端から始める。旧モデルより難しいタスクを与え、スコープ確認・質問・実行の流れを観察する | Fable 5 | P7 |
| S22 | 長時間タスクでは自己検証を明示する。別コンテキストの検証サブエージェントが自己批判より優れる傾向 | Fable 5 | P7 |
| S23 | 曖昧なタスクでの過剰計画を防ぐには「行動するのに十分な情報があれば行動せよ」と指示する | Fable 5 | P7 |
| S24 | 高 effort での不要な整頓・リファクタを防ぐには「タスクに必要な以上の機能追加・リファクタ・抽象化をするな」と境界を明示する | Fable 5 | P7 |
| S25 | Fable 5 は単一リクエストが数分、自律実行が数時間に及ぶことがある。クライアントのタイムアウト・ストリーミング・進捗表示を移行前に調整する | Fable 5 | P7 |
| S26 | 旧モデル向けの過剰な指示（スキル含む）は Fable 5 では出力品質を下げうる。既定挙動で十分なら削除する | Fable 5 | P7 |
| S27 | send_to_user のようなツールは、定義だけでは呼ばれにくい。システムプロンプトで「ユーザーが逐語で読むべき内容のときに呼べ」と明示する | Fable 5 | P7 |
| S28 | Fable 5 は攻撃的サイバーセキュリティ・生物/生命科学向けではない。該当領域は stop_reason:"refusal" を返しうる | Fable 5 | P3, P7 |
| S29 | Fable 5 の refusal は HTTP 200 の成功応答として stop_reason:"refusal" を返す。stop_details.category に "cyber"/"bio"/"reasoning_extraction" 等が入る。Opus 4.8 へのフォールバックを設計する | Fable 5 | P3, P12 |

### Opus 4.8 固有のプロンプティング挙動

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S30 | Opus 4.8 は指示を極めて字義的に解釈する。命令を暗黙に一般化しない。広く適用したいならスコープを明示する（例：「最初のセクションだけでなく全セクションに適用せよ」） | Opus 4.8 | P8 |
| S31 | Opus 4.8 は応答長をタスクの複雑さに合わせて調整する（固定の冗長さを既定にしない）。特定の長さ・スタイルが要るなら明示する | Opus 4.8 | P8 |
| S32 | Opus 4.8 は推論をツール呼び出しより優先する傾向。ツール使用を増やすには effort を上げる（high/xhigh でエージェント検索・コーディングのツール使用が大幅増）か、いつ・どうツールを使うか明示する | Opus 4.8 | P8 |
| S33 | Opus 4.8 は既定でサブエージェントを少なめに起動する。単一応答で完結できる作業にサブエージェントを起動しない。並列化したいならスコープを明示する | Opus 4.8 | P8 |
| S34 | max / xhigh effort で走らせるなら、大きな max output トークン予算を設定する。64k から始めて調整する | Opus 4.8 | P8 |
| S35 | 正の例（望む長さ・深さの応答例）を示す方が「冗長にするな」等の否定指示より効果的 | 全モデル | P8, P10 |
| S36 | Opus 4.8 は直接的で断定的な文体に寄る。温かい/会話的な声が要るなら明示的に追加する（例：「温かく協調的なトーンで。ユーザーの枠組みを認めてから答えよ」） | Opus 4.8 | P8 |
| S37 | Opus 4.8 は一貫した既定デザイン（クリーム背景・セリフ体・テラコッタ差し色）を持つ。ダッシュボード/開発ツール/フィンテック等には不向き。「クリームを使うな」等の汎用指示より、具体的なデザイン方向の指定が効く | Opus 4.8 | P8 |

### Sonnet 5 固有のプロンプティング挙動

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S38 | Sonnet 5 は応答長をタスクの複雑さに合わせる。冗長さを抑えたいなら明示する（例：「簡潔で焦点を絞った応答を。非本質的な文脈は省き、例は最小限に」） | Sonnet 5 | P9 |
| S39 | Sonnet 5 は指示を字義的・明示的に解釈する（特に低 effort）。正の例が否定指示より効果的 | Sonnet 5 | P9 |
| S40 | 複雑な問題で浅い推論が見えたら、プロンプトで回避せず effort を high/xhigh に上げる。低 effort を保つ必要があるなら「多段推論を要する。慎重に考えてから答えよ」と的を絞って指示 | Sonnet 5 | P9 |
| S41 | Sonnet 5 は Sonnet 4.6 より既定でエージェント的。ツールに手を伸ばし自己検証ループを回しやすい。thinking off だとツールに手を伸ばしにくいので、off で使うなら明示的に促す | Sonnet 5 | P9 |
| S42 | Sonnet 5 は新トークナイザで、同じテキストで約 30% 多くトークンを生成する。max_tokens が Sonnet 4.6 向けだと切り詰められうる。予算を見直す | Sonnet 5 | P5, P9 |
| S43 | high/xhigh/max effort では max_tokens に余裕を持たせる。予算が厳しいと応答がほぼ thinking で埋まり本文が truncate され stop_reason:"max_tokens" になりうる | Sonnet 5 | P9 |
| S44 | Sonnet 5 は初の Sonnet ティアのリアルタイム・サイバーセキュリティ保護あり。禁止・高リスクのサイバー話題は refusal（HTTP 200, stop_reason:"refusal"）を返しうる | Sonnet 5 | P5 |
| S45 | Sonnet 5 は進捗更新を既定で高品質に出す。「3 ツール毎に要約」等の強制スキャフォールドを入れているなら外して試す | Sonnet 5 | P9 |

### 全モデル共通

| source_id | 主張 | 対象 | 出典 |
| --- | --- | --- | --- |
| S46 | Claude は明確で明示的な指示によく応答する。「上をいく」挙動が欲しいなら明示的に要求する。文脈の乏しい同僚に見せて従えるか、が黄金律 | 全モデル | P6 |
| S47 | 一般的な指示が、手書きの逐一プランより良い推論を生むことが多い（例：「徹底的に考えよ」）。Claude の推論はしばしば人間の指定を超える | 全モデル | P6 |
| S48 | 最新モデルはサブエージェントをネイティブに統率する。並列実行・独立コンテキスト・独立ワークストリームのときサブエージェントを使う。単純・逐次・単一ファイル編集は直接やる | 全モデル | P6 |
| S49 | Claude Code で Anthropic API では opus が Opus 4.8 に、sonnet が Sonnet 5 に解決される。特定版に固定するにはフルモデル名（例：claude-opus-4-8）を使う | 全モデル | P11 |
| S50 | Fable 5 は Claude Code で最も高能力なモデルで、一度に収まらない大きなタスクに適する | Fable 5 | P11 |
