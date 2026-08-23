---
alwaysApply: true
title: ドキュメント運用
type: rule
description: ドキュメントの置き場所・ライフサイクル（wip/plans/wip/worklogs/spec/ddr/HANDOFF）を定めたルール
tags: [docs, workflow, rule]
keywords: [wip, plans, handoff, worklogs, 正史仕様, 意思決定ログ, ライフサイクル, issue-mr-flow, ループ進捗, always-apply]
---

# ドキュメント運用

開発フロー全体（issue起票〜マージ）は `.claude/skills/issue-mr-flow/SKILL.md` を参照する
（唯一の実装フロー定義）。本ファイルはドキュメントの置き場所・ライフサイクルの参照表であり、
手順そのものは記載しない。

情報の寿命（ライフサイクル）と「誰のためのドキュメントか」で置き場所を切り分ける。

| ファイル | 対象 | 寿命 | 内容 | 運用 |
|---|---|---|---|---|
| `CLAUDE.md` / `.claude/rules/*.md` | AI専用 | 永続 | 規約・構成 | ルート直下・`.claude/rules/`。セッション開始時にAIが自動読込する。実装フローそのものは `.claude/skills/issue-mr-flow/SKILL.md` を参照。 |
| `wip/plans/<自動命名>.md`（**全体作業計画**） | 人間＋AI | 生成時点のスナップショットとして永続 | このissueをどう進めるかの全体像（何を調査し何を実装するか）・比較検討した案・承認記録。**フェーズ2〈調査〉・フェーズ4〈反映〉の節は必ず含める**（詳細: `.claude/skills/issue-mr-flow/SKILL.md`「全体作業計画に必ず含めるフェーズ」） | **planツール（Planモード）で作成**し、issue（ブランチ）につき1つだけ持つ。ファイル名はハーネスが提示する自動命名のまま使う。手動で使い回したり中身を空にしたりせず、そのままコミットして履歴に残す。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「計画の2階層構造」 |
| `wip/plans/【種別】タスク内容.md`（**個別調査計画**（フェーズ2）／**個別作業計画**（フェーズ3）／**個別反映計画**（フェーズ4）） | 人間＋AI | 同上 | フェーズごとの詳細な計画（**「これから何をするか」のみ。実施した結果は書かず`wip/reports/…md`へ分離する**。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。種別は`【調査】【設計】【実装】【テスト】【AIアセット作成】【設計反映】【AIアセット反映】【実装反映】`の8種（issue #110で拡張。`【AIアセット作成】`はフェーズ3、`【実装反映】`はフェーズ4に属する）。**合意を1回で取るなら併記**（例`【実装】【テスト】`）、**フェーズごとに合意を挟むなら分ける**（迷ったら分ける。各種別の定義・判断基準の詳細は`.claude/skills/issue-mr-flow/SKILL.md`「計画の2階層構造」「種別を複数併記する場合／分ける場合」） | **planツールは使わず**Write/Editで直接作成する。囲み文字は全角`【】`（ASCIIの`[]`はbashのglobで文字クラス扱いになり、`wip/plans/[調査]*.md`が意図どおりマッチしないため使わない）。`wip/plans/【*.md`で下位の個別計画（調査・作業・反映）のみを機械的に列挙できる。 |
| `wip/plans/<全体作業計画・個別計画と同名>.html`（**計画のHTMLビュー**） | 人間＋AI | 同上 | 上記mdの内容を視覚的にまとめた自己完結HTML（人間レビュー用ビュー）。**計画の正文はmd側であり、HTMLはその視覚化**（両者は併存させる） | flow-id 1-4（全体作業計画）・2-1・3-1・4-1（個別計画）で、**対応するmdを作る場合に**作成し、md側の内容と同期して更新する（フェーズごと省略した回はmd自体が無いのでHTMLも無い。**作成の要否の正は`.claude/skills/issue-mr-flow/SKILL.md`の各flow-idの記述であり、ここでは条件を再掲しない**）。土台は`.claude/skills/issue-mr-flow/assets/plans.template.html`（見出し構成の正はテンプレート側。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「計画・レポートのHTMLビュー」。issue #54）。**ファイルの削除はflow-id 5-5**で`wip/worklogs/` `wip/reports/`とまとめて行う。`.gitignore`には加えない。squash mergeにより、mainには残さない。 |
| `HANDOFF.md` | 人間＋AI | 短期（常に最新状態のみ） | `.claude/skills/issue-mr-flow/SKILL.md`の全体フロー（5フェーズ・43ステップ）に対応する進捗チェック表／現在地／次にやること／判断を迷った内容／未解決の内容／守るべき条件・触ってはいけない範囲 | Git管理下に置く。**flow-idが1つ進むごとに、完了したflow-idの行を`[x]`にし「やったこと」「次にやること」を書き換える**（更新はcommit（flow-id 2-2/2-7/3-2/3-7/4-2/4-7/5-4/5-6）より前に行い、同じcommitに含める）。進捗表の記号・ヘッダ情報（issue/ブランチ/PR/push回数/現在のループ/未返信スレッド）の更新は`.claude/scripts/src/update-handoff-progress.sh`（`mark-done`/`mark-skip`/`add-round`/`set-header`）で機械的に行う（**ヘッダ行の正しい表記は`.claude/docs/spec/update-handoff-progress.md`「HANDOFF.mdのヘッダ行」が正**。issue #66。ここには再掲しない）（PR作成後は`- 追従監視:`行もヘッダへ持たせ、こちらは手で書き換える。`set-header`の対象外。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「PR作成後のdefaultブランチ追従（監視）」）（手作業でのテーブル編集を禁止するものではないが、記号の書き間違いを避けるため推奨する。詳細: `.claude/docs/spec/update-handoff-progress.md`）。詳細な試行錯誤は書かず `wip/worklogs/` に逃がす。flow-id 5-5で次のタスクへ向けてリセットする。 |
| `wip/worklogs/日付_<全体計画名>_<個別計画名>_push<N>.md` | AI専用（人間も参照可） | タスク（issue／ブランチ）単位（flow-id 5-5でまとめて削除。ファイル自体はpushごとに`_push<N>`で分ける） | 「何を試した／うまくいった／ダメだったか」の詳細ログ | 個別作業計画の作成時に作り、同じセッションで作業する間に作業の節目ごとに頻繁に書き足す。内容はflow-id 4-6（設計反映）でspec/ddrへ反映し、**ファイルの削除はflow-id 5-5**で`wip/plans/` `wip/reports/`とまとめて行う（削除自体もコミットに含める）。`.gitignore`には加えない（ブランチ上のコミット履歴として残すため）。squash mergeにより、mainには残さない。 |
| `wip/reports/日付_<全体計画名>_<内容を簡潔に>.md` | 人間＋AI | タスク（issue／ブランチ）単位（worklogと同様、flow-id 5-5でまとめて削除） | **実施結果の正文**。調査結果・作業結果・反映結果と、その結論・根拠・確認結果（計画ファイルへは書かない） | flow-id 2-6/3-6/4-6で作成し、レビュー往復（2-9/3-9/4-9）のたびに更新する。**個別計画（`wip/plans/【*】〜.md`）へ結果を書かないための分離先**（詳細: `.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。見出し構成は規定しない（記述の型のテンプレート化はissue #54の担当）。内容はflow-id 4-6（設計反映）でspec/ddrへ反映し、**ファイルの削除はflow-id 5-5**で`wip/plans/` `wip/worklogs/`とまとめて行う（削除自体もコミットに含める）。`.gitignore`には加えない。squash mergeにより、mainには残さない。 |
| `wip/reports/日付_<全体計画名>_<内容を簡潔に>.html` | AI専用（人間も参照可） | 同上 | 上記mdの内容を視覚的に分かりやすくまとめた自己完結HTML（人間レビュー用ビュー）。**結果の正文はmd側であり、HTMLはその視覚化**（両者は併存させる） | flow-id 2-6・3-6・4-6（および5-4の統括レポート）で作成し、md側の内容と同期して更新する。土台は`.claude/skills/issue-mr-flow/assets/reports.template.html`（見出し構成の正はテンプレート側。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「計画・レポートのHTMLビュー」。issue #54）。**ファイルの削除はflow-id 5-5**で`wip/plans/` `wip/worklogs/`とまとめて行う（削除自体もコミットに含める）。`.gitignore`には加えない（ブランチ上のコミット履歴として残すため）。squash mergeにより、mainには残さない。 |
| `.claude/docs/spec/機能名.md` | 人間＋AI | 永続（最新状態） | 背景・目的／仕様／影響範囲／設定項目／未決定事項・懸念点 | 「現在の正史」。実装完了のたびに最新仕様へ上書きする。新規作成時の人間承認は必須。plans／worklogの内容はflow-id 4-6（設計反映）で反映する。 |
| `.claude/docs/ddr/i<issue番号>-<枝番2桁>-タイトル.md` | 人間＋AI | 永続（本文は不変） | 「〇〇を検討したが✕✕を採用した」という意思決定の背景・却下案（DDR: Design Decision Record。architectureに限らない意思決定を対象とする） | **issue番号ベースの識別子**で管理する（issue #133。旧方式の4桁連番は全件改番済みで、本リポジトリには残っていない。命名・枝番・`i00`（対応issueが無いDDR）の詳細は `.claude/rules/markdown-frontmatter.md`「DDRの識別子」が正）。一度マージしたら**本文**は追記のみ（変更不可）。ただし**YAML frontmatterのみは後から更新してよい**（後続のDDRで無効になった場合に`status: superseded` / `superseded_by`を付ける。詳細: `.claude/rules/markdown-frontmatter.md`「DDRのstatus」）。`spec` の未決定事項が解消したら記録し、spec側の該当項目は削除してよい。plans／worklogの内容はflow-id 4-6（設計反映）で反映する。**DDRを追加・変更したら、`.claude/docs/README.md` のDDR一覧を手書きせず `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、出た差分を同じコミットに含める**（一覧は生成物。行の内容はfrontmatterの`status`/`superseded_by`/`note`だけから決まる。issue #135。仕様: `.claude/docs/spec/generate-ddr-list.md`、経緯: `.claude/docs/ddr/i0135-01-DDR一覧は生成物にしつつGit管理下へ残す.md`）。 |
| `<ディレクトリ>/REVIEW-POINTS.md` | 人間＋AI | 永続（最新状態） | そのディレクトリ配下すべて（孫以下を含む）に適用するレビュー観点（`type: review-points`） | 各ディレクトリ直下に置く。敵対的レビュー（`.claude/skills/adversarial-review/SKILL.md`）と `review-points` スキルが祖先方向へ遡って集めて使い、人間のレビューでも参照する。**`wip/plans/` `wip/reports/` 配下に置かれていてもflow-id 5-5の削除対象に含めない**（下記）。仕様: `.claude/docs/spec/adversarial-review.md`「レビュー観点（REVIEW-POINTS.md）」 |

**`wip/reports/` の `.html` は flow-id 2-6・3-6・4-6 のいずれでも作成する**（issue #54。issue #33 時点では
2-6 のみ必須で 3-6・4-6 は任意だったが、記述の型がテンプレートへ切り出され生成コストが下がったため、
`.claude/rules/docs-workflow.md` が元々定めていた「調査結果に限らず設計・実装・AIアセット反映等の報告」
という用途どおりに揃えた）。**`.md` と `.html` は必ず内容を同期させる**（片方だけ更新しない）。
`wip/plans/` の `.html` も同じで、flow-id 1-4・2-1・3-1・4-1 で md と対にして作る。

`wip/plans/` `wip/worklogs/` `wip/reports/` の3つは、いずれも**flow-id 5-5（次タスクのための片付け）でまとめて
削除する**（`wip/reports/` はmd・htmlの両方が対象。`.claude/skills/issue-mr-flow/SKILL.md`の全体フローが正）。設計反映（flow-id 4-6）で
行うのは、これらの**内容**を`.claude/docs/spec/` `.claude/docs/ddr/`へ反映することであって、
ファイルの削除ではない。削除済みの状態でPR作成〜squash mergeへ進むため、mainにはこれらのファイルは
残らない。この削除と`HANDOFF.md`のリセットは`bash .claude/scripts/src/cleanup-task.sh`が行う
（`wip/worklogs/TEMPLATE.md` と、下記の `REVIEW-POINTS.md` は削除対象から除外される。仕様:
[.claude/docs/spec/cleanup-task.md](../docs/spec/cleanup-task.md)）。

**唯一の例外が `REVIEW-POINTS.md` である。** `wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md` は
これらのディレクトリ配下にあるが、タスク単位の成果物ではなく**そのディレクトリに対するレビュー観点**
であり、寿命は永続である（上表）。flow-id 5-5で `wip/plans/` `wip/worklogs/` `wip/reports/` を片付ける際は、
**`REVIEW-POINTS.md` を残す**（issue #77）。worklogの雛形である `wip/worklogs/TEMPLATE.md` も同様に残す
（`cleanup-task.sh` はこの2つを削除対象から除外する）。

上記の`spec`/`ddr`は、このリポジトリに同梱されたissue駆動MRワークフロー機構自体（`.claude/`配下）の
ものである。アプリ本体を追加する場合は、そのアプリ専用の`docs/spec/`・`docs/ddr/`（必要なら人間専用
ツール用の`dev-tools/docs/`）を同じ表の運用ルールで新設し、`.mrworkflow.json`の`specDirs`/`ddrDirs`に
追記することを検討する（詳細: `.claude/rules/directory-structure.md`「配置の指針」）。

`HANDOFF.md` は空でも各見出し（現在地／次回やること等）だけを残した状態でルート直下に存在させておき、使うときに埋める運用とする（都度新規作成はしない）。

**コード・スクリプト内のコメントから `wip/plans/` `wip/worklogs/` `wip/reports/` のファイルを参照しない**
（issue #9対応時に発覚: `.claude/hooks/`配下の5ファイルが `# 設計: plans/jazzy-giggling-crescent.md`
のように**flow-id 5-5で削除済みのplanファイル**を参照しており、読み手が辿れない状態になっていた）。
これらはタスク単位（flow-id 5-5）で削除される寿命の短いファイルであり、コード側の恒久的な参照とは
ライフサイクルが噛み合わない。**恒久的に参照してよいのは、issue番号（GitHub/GitLab上に残る）と
`.claude/docs/spec/` `.claude/docs/ddr/` 配下のファイル**である。

```bash
# 悪い例（planは削除されるため参照が切れる）
# 設計: plans/groovy-zooming-balloon.md（issue #15）
# 良い例
# 設計: issue #15 → .claude/docs/spec/issue-mr-workflow.md
```

**ファイル移動に伴うパス参照の一括置換は、`docs/ddr/*.md`の本文および`docs/spec/*.md`内の
過去issueごとのchangelog（「影響範囲」節等、point-in-timeの記録として書かれた節）を対象に含めない**
（issue #24対応時に実際に発生: `sed`による機械的なパス一括置換で、移動した仕様書の過去changelog
エントリまで新パスへ書き換えてしまい、当時存在しなかったパスが過去の記録に紛れ込む形で歴史を
破壊しかけた）。ファイル移動時にパス参照を更新してよいのは、現在の状態を説明する節
（「## 仕様」等）のみ。移動そのものの記録は、changelogへの**新規エントリの追記**として残す。
DDRは本文を一切変更せず、`git mv`による位置の移動のみを行う（frontmatterの`status`更新は
この制限の対象外。上記のDDR行を参照）。

**DDR番号の繰り下げ（改番）でも、この制限は同じように効く**（issue #47対応時に実際に踏んだ）。
`main` を取り込んだ結果DDR番号が衝突し、`sed` で `0059`→`0061` を一括で当てたところ、
**`main` 由来の過去changelogエントリまで書き換えて**しまった（そのissueが追加したDDRは
改番の対象ではないのに、番号だけがすり替わる）。改番の手順自体は
`.claude/skills/resolve-conflict/SKILL.md`「類型A」が正で、**改番後は
`git diff <ブランチ分岐点のSHA> -- .claude/` の削除行がゼロであることで確認する**
（引数なしの `git diff` は作業ツリー比較のため、その1回の実行以降に入るコミットを見ない。
DDR一覧そのものは生成物なので、`generate-ddr-list.sh` の再実行で追随する）。

**flow-idの繰り下げのような横断的な棚卸しでは、`wip/plans/` `wip/worklogs/` `wip/reports/` を
一括で対象外にしない**（issue #70対応時に実際に踏んだ）。これらはタスク単位で削除される寿命の
短いディレクトリなので、棚卸しの対象から外すのが基本である。しかし**`wip/plans/REVIEW-POINTS.md`
と `wip/reports/REVIEW-POINTS.md` だけは、そのディレクトリの直下にありながら寿命が永続**であり
（上表・flow-id 5-5の削除対象外）、ディレクトリ単位で除外するとこの2ファイルだけがすり抜ける。
実例では `reports/REVIEW-POINTS.md` の `flow-id 5-4` が繰り下げ漏れとして残り、敵対的レビューで
初めて見つかった。**除外はディレクトリ単位ではなくファイル単位で判断する。**

**既存ドキュメントへ新しい見出しを差し込むときは、挿入位置の直前の節が「その節全体にかかる地の文」で
終わっていないかを必ず確認する**（issue #64対応時に実際に発生）。終わっている場合、間に別の節を挟むと、
その地の文が新しい節にかかっているように読めてしまう。挿入位置を節の末尾（次の見出しの直前）へ回すなど、
係り先が変わらない位置を選ぶ。

- 実例: `issue-mr-flow/SKILL.md` の `### 計画の2階層構造` は、末尾に節全体へかかる地の文
  （囲み文字の注意・`plans/【*.md`での機械的列挙・flow-id 1-4の判定）が続いていたため、その直後ではなく
  `## サブコマンド` の直前へ新節を入れた。
- **同じ節名でもファイルごとに結論が変わる。** 同じ作業で `.claude/docs/spec/issue-mr-workflow.md` の
  同名節を見たところ、直後に地の文が無く、当初の位置のままで問題なかった。「別のファイルで同じ位置へ
  入れられたから安全」とは判断せず、ファイルごとに確認する。

`HANDOFF.md`の「フロー進捗状況」表（`.claude/skills/issue-mr-flow/SKILL.md`の全体フローに対応）は、
**どの行も進捗記号を1つだけ持つ**。「〜を合意まで繰り返す」と書かれたループ扱いのステップ
（例: 2-3〜2-4, 2-6〜2-9, 3-3〜3-4, 3-6〜3-9, 4-3〜4-4, 4-6〜4-9）も例外ではなく、
レビュー往復が何回になっても記号は増えない。同じループ範囲内のステップは常に同じ記号を持つ
（例: 2-8と2-9は常に同じ）。
**ループ範囲は「1周（レビュー往復1回）が完全に完了して初めて`[x]`にする」という単位であり、
範囲内の一部ステップだけを個別に完了扱いにすることはできない**（`update-handoff-progress.sh`は
この制約を機械的に強制する。詳細: `.claude/docs/spec/update-handoff-progress.md`「制約・設計判断」）。

**「1周が完全に完了した」の条件は2つある**（issue #70）。

1. そのループのレビュー指摘を**成果物へ反映した**こと。
2. **返信が1件も付いていないレビュースレッドが無い**こと（人間の指摘・敵対的レビューの投稿の
   両方を含む。判定方法は`.claude/skills/issue-mr-flow/SKILL.md`「レビュー完了合図の確認」の(2)）。

2を満たしたら`update-handoff-progress.sh set-header --unreplied 0`でヘッダへ記録する。
**ループ範囲への`mark-done`は、この値が0でなければ（行が無い場合も）拒否する。**
1だけを満たして`[x]`にできてしまうと、返信ゼロのスレッドが「未対応と区別が付かない」まま残る
（実例: issue #70のフェーズ2で敵対的レビューの10件が約1日この状態だった。
詳細: `.claude/docs/spec/update-handoff-progress.md`「ループ範囲への`mark-done`と未返信スレッド」）。

**レビュー往復が何周目かは、進捗表ではなくヘッダの1行が持つ**（issue #58）。ヘッダ項目
（`- push回数:`等）と同じブロックに、次の1行を置く。

```
- 現在のループ: 3-6〜3-9 の3周目（進行中）
```

- 書式は`<開始flow-id>〜<終了flow-id> の<N>周目（進行中|完了）`。ループ範囲の外にいる間は
  `- 現在のループ: なし`と書く。
- **周回数の記録場所はこの1行だけで、進捗表には持たせない。** 以前は往復1回につき`[]`を1つ足して
  `[x][x][]`のように表現していたが、(1) 周回数を得るのに同一トークンの数え上げが要り、往復が
  増えるほど誤読しやすい、(2) 周回数は本来ループ範囲につき1つの値なのに範囲内の全行（最大4行）へ
  同じ文字列が複製される、(3) 末尾の`[]`が「未着手」と「進行中」のどちらなのか表から判別できない、
  という3点の読みにくさがあったため廃止した。
- この行は手で書き換えず、`update-handoff-progress.sh`の`add-round`（周回数を1つ進めて範囲の記号を
  `[]`へ戻す）／ループ範囲への`mark-done`（周回数は据え置いて状態を「完了」にする）に任せる。
  ループ範囲の外へ出たときなど、表から決まらない値を入れる場合だけ`set-header --loop <text>`を使う。
- **ループ範囲の外から中へ「初めて」入るときも、`add-round`ではなく`set-header --loop`を使う**
  （issue #127で実際に踏んだ）。そのループ範囲の進捗列はまだ`[]`のため、`add-round`は
  「前回の往復が未完了の可能性」として拒否する（エラー条件の詳細は
  `.claude/docs/spec/update-handoff-progress.md`が正）。**`add-round`は2周目以降へ進めるための
  コマンドであり、1周目を開始するためのものではない。**

  ```bash
  # 1周目を開始する（フェーズ4の反映ループへ初めて入る）
  bash .claude/scripts/src/update-handoff-progress.sh set-header --loop '4-6〜4-9 の1周目（進行中）'
  # 2周目以降へ進む
  bash .claude/scripts/src/update-handoff-progress.sh add-round 4-6
  ```
- 旧表記（`[x][x][]`）の`HANDOFF.md`は、次に`add-round`／`mark-done`を実行した時点で自動的に
  移行する（記号の個数を周回数としてヘッダへ移し、進捗列は記号1つへ畳む）。手作業での書き換えは要らない。

進捗記号 `[-]`（今回は実施しないフェーズ・スキップ）は、**フェーズ単位・ループ範囲単位でまとめて
実施しない**場合に使う（例: フェーズ2〈調査〉を丸ごと省略する）。ループ範囲内の一部ステップだけを
`[-]`にする使い方は想定しない（上記の「範囲内の一部だけ完了扱いにできない」という制約と表裏一体の
ため、部分的なスキップは記号の不整合を招く）。**`update-handoff-progress.sh`の`mark-skip`は
ループ範囲へ伝播しないので、範囲を丸ごと省略するときは範囲内の全flow-idを渡す**（一部だけ渡すと
記号が揃わないためエラーになり、1件も書き換えられない。issue #140。詳細:
`.claude/docs/spec/update-handoff-progress.md`「`mark-skip`とループ範囲」）。

**`[-]` を決めてよいのは、そのフェーズの直前に立つ個別計画を作る時点（フェーズ2なら flow-id 2-1、
フェーズ4なら flow-id 4-1）以降**である。flow-id 1-4 で全体作業計画を書く時点で先回りして
フェーズ2・4の行を `[-]` で埋めない（計画に節が無いと、後から必要だと分かっても拾い直す先が
無くなるため）。全体作業計画に必ず含めるフェーズ・そのための事前調査をどこまでやるかは
`.claude/skills/issue-mr-flow/SKILL.md`「全体作業計画に必ず含めるフェーズ」が正である。

**非対話的実行環境（Claude Code on the webのリモート実行環境等、人間のレビュー往復を待てない
セッション）で、人間担当のレビュー待ちステップ（例: 3-3/3-4, 3-8/3-9）を省略する場合**、該当する
ループ範囲の進捗記号は`[]`のまま残し、実際に実施した内容（例: 3-6〈作業実施〉・3-7〈commit〉相当は
行った）は「やったこと」セクションの文章で補足する。ループ範囲の記号を無理に`[x]`や`[-]`にしないこと
（前者は「1周完了」という意味と矛盾し、後者は「実施しない」という意味と矛盾するため）。
