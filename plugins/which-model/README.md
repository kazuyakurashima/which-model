# which-model

Claude Code で、タスクに適したモデルと effort を理由つきで提案し、
確定したモデル向けにプロンプトを最適化して表示するプラグインです。
モデルは自動で切り替えません。タスクも自動では実行せず、表示されたプロンプトを
確認して `g` を送ったときだけ実行する設計です（`g` の再送では再実行しません）。

使い方: `/which-model:pick <やりたいこと>`

詳細: https://github.com/kazuyakurashima/which-model
