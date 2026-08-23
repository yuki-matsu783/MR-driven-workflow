---
title: 配布テンプレート資産（PR/MRテンプレート・.gitattributes・VERSION）
type: spec
description: 他プロジェクトへ配布するテンプレート資産の内容と、配布経路上での扱いの仕様
tags: [spec, distribution, template]
keywords: [pull_request_template, merge_request_templates, gitattributes, VERSION, sync-assets, install-to-project, 行追記, 冪等, 版管理]
---

# 配布テンプレート資産（PR/MRテンプレート・`.gitattributes`・VERSION）

## 背景・目的

issue #33。このリポジトリは他プロジェクトへワークフロー機構を配布するテンプレートだが、
受け入れ側が必要とする基本資産のうち次が欠けていた。

- PR/MRテンプレート（issueテンプレートだけがあり、MR側が資産化されていなかった）
- `.gitattributes`（LF改行の保証が各開発者の `core.autocrlf` という個人環境依存だった）
- 配布物の版を識別する手段（配布先が「どの版の資産を導入したか」を判別できなかった）

LICENSEも当初の対象だったが、**同梱しないと決めた**（
[DDR i0033-02](../ddr/i0033-02-配布テンプレートにLICENSEを同梱しない.md)）。

## 仕様

### PR/MRテンプレート

| ファイル | プロバイダ |
|---|---|
| `.github/pull_request_template.md` | GitHub |
| `.gitlab/merge_request_templates/Default.md` | GitLab（`Default.md` は既定適用される予約名。DDR i0032-01と同じ理由） |

**両者の見出し構成は、`issue-mr-flow` の `describe` サブコマンドが生成するdescriptionと同一**に
する（`Closes #<issue番号>` → `## Plan` → `## 実装状況`）。

- **見出しを増やさない。** `describe` は `set_mr_description` でdescriptionを**全文置換**するため、
  テンプレートにしか無い見出しは flow-id 2-5 の初回 `describe` で消える。
- **記入ガイドはHTMLコメントで置く。** GitHub/GitLabの表示に出ず、`describe` に置換されても
  情報を失わない。
- **frontmatterを付けない。** issueテンプレートと同じ理由で、本文へYAMLがそのまま挿入されるため
  （`.claude/rules/markdown-frontmatter.md`「対象外・特殊対応ファイル」）。

### `.gitattributes`

本家（このリポジトリ）の内容は次の2行。

| 行 | 目的 | 配布 |
|---|---|---|
| `* text=auto` | リポジトリ内部でテキストをLFで保持する、リポジトリ全体の正規化方針 | **配らない** |
| `*.sh text eol=lf` | `.sh` を作業ツリーでも必ずLFにする（CRLFだと `bash: $'\r': command not found` で動かない） | **配る** |

`* text=auto` を配らないのは、リポジトリ全体の正規化方針は配布先が決めるべきものであり、
勝手に足すと配布先の既存ファイルが次のコミットで一斉に正規化されうるためである。

**どの行を配るかは、この `.gitattributes` 自身がマーカーで示す。**

```gitattributes
# --- dist:begin ---
*.sh text eol=lf
# --- dist:end ---
```

`install-to-project.sh` はマーカーの間の行（コメント・空行を除く）だけを読んで配布先へ追記する。
配る行の定義を**このファイル1箇所**に持たせ、スクリプト側へ書き写さないための仕組みである
（書き写すと、本家へ配布したい行を足しても配布先へ届かない状態になる）。配布対象へ足してよいのは
「配布したスクリプトが動くのに必要な指定」だけで、リポジトリ全体の方針は入れない。

### `.claude/VERSION`

- **形式**: SemVer（`MAJOR.MINOR.PATCH`）1行のみ。初期値は `0.1.0`。
- **位置**: リポジトリルートではなく `.claude/` 配下（配布先が自分のアプリの版として `VERSION` を
  持つ場合に、それを上書きしないため）。
- **CHANGELOGは持たない。** 変更内容はコミット履歴／PR一覧で辿る
  （[DDR i0033-01](../ddr/i0033-01-配布物の版はVERSIONファイル1つで表しCHANGELOGを持たない.md)）。
- **更新のタイミング**: flow-id 4-6（AIアセット反映）。配布対象アセットに変更があった回だけ行う。
- **増分の決め方**: AIエージェントが増分を**提案**し、**人間が決める**（AIが独断で上げない）。

  | 増分 | 目安 |
  |---|---|
  | `MAJOR` | 配布先に手作業を要求する非互換変更（配置場所の変更・必須スクリプトの引数変更など） |
  | `MINOR` | 資産の追加・フローの拡張 |
  | `PATCH` | 文言修正・バグ修正 |

- **人間の判断で据え置くことがある。** 増分を決めるのは人間なので、配布対象アセットが変わった回
  でも「今回は上げない」という結論になりうる（実例: issue #54。`.claude/skills/issue-mr-flow/assets/`
  へテンプレート2本を新設し `canvas-report/templates/` → `assets/` の改名も行ったが、`0.1.2` の
  まま据え置いた）。**据え置く場合は、そのissueのspecのchangelogへ据え置いた事実を残す。**
  上の「配布対象アセットに変更があった回だけ行う」を読んで「VERSIONは配布アセットの変更に必ず
  追随している」と信じないための断りである。
  - **据え置きには実害がある**ことを承知して選ぶ。配布先は同じ版のまま中身の違う `.claude/` を
    受け取るため、**版から資産の差を判別できない**。とくに改名・削除を伴う回は、
    `install-to-project.sh` が上流で消えたファイルを配布先から削除しない（コピーのみ）ため、
    配布先に旧パスが残ったことに気づく手掛かりが版にも無くなる。

### 配布経路での扱い

配布は `apply-mr-workflow-to-project` スキルの2スクリプトが担う（本家 → `assets/` →配布先）。

| 資産 | `sync-assets.sh` | `install-to-project.sh` | 配布先の既存ファイルの扱い |
|---|---|---|---|
| PR/MRテンプレート | `.github/` `.gitlab/` のディレクトリ単位コピーに載る | `safe_copy_dir` | 差分があれば `.bak` 退避のうえ上書き（他資産と同じ） |
| `.claude/VERSION` | `.claude/*` のループに載る | `safe_copy_dir`（`find -type f`）＋ `ALWAYS_OVERWRITE_RELPATHS` | **`.bak` を作らず常に上書き**（下記） |
| `.gitattributes` | ルートファイルの列挙へ明示的に追加（配る行の定義をマーカーで持つため、`assets/` へ集める必要がある） | **行追記**（`ensure_gitattributes_rules` が `assets/.gitattributes` のマーカー間の行を読む） | **上書きしない**。必要な行が無ければ末尾へ足すだけ |

`.claude/VERSION` を通常の「差分があれば `.bak` 退避して警告」の対象にすると、**版を上げた回は
必ず**警告と `.bak` が出る。VERSIONは配布元が所有する値であって配布先のカスタマイズではないため、
この警告は誤りであり、本当に手を入れるべき差分（`AGENTS.md` 等）の警告を埋もれさせる。
`install-to-project.sh` の `ALWAYS_OVERWRITE_RELPATHS` に列挙し、`.bak` も警告も出さずに上書きする。

`.gitattributes` の行追記には次の性質がある（
[DDR i0033-03](../ddr/i0033-03-gitattributesは配布先へ丸ごとコピーせず必要な行だけ追記する.md)）。

- **冪等**: 何度適用しても行が増えない。
- **行全体の一致で判定する**（`grep -Fxq`）。部分一致にすると、配布先が
  `# *.sh text eol=lf を入れるか検討中` のようにコメントで言及しているだけでも「もう有る」と
  誤判定し、必要な指定が入らないまま無言で終わる。
- **判定の前にCRを落とす。** Git for Windowsの既定（`core.autocrlf=true`）では配布先の
  `.gitattributes` が作業ツリーでCRLFになる。`*.sh text eol=lf` は `.gitattributes` 自身には
  効かないため、一度コミットされた配布先の `.gitattributes` は以後ずっとCRLFで取り出される。
  CRを落とさずに行全体の一致を見ると毎回「まだ無い」と判定し、**適用のたびに同じ行が追記され
  続ける**（この機構が主に想定するWindows環境でこそ壊れる）。
- **末尾に改行が無いファイルへも安全に追記する**（追記前に改行を1つ補う）。
- **配る行が1件も読めなかった場合は、無言でスキップせず件数付きの警告を出す**（マーカーの
  書き間違いで配布が静かに空振りするのを防ぐため）。

## 影響範囲

### issue #33（初版）

- 追加: `.github/pull_request_template.md`、`.gitlab/merge_request_templates/Default.md`、
  `.gitattributes`、`.claude/VERSION`。
- 変更: `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh`（ルート列挙へ
  `.gitattributes` を追加）、同 `install-to-project.sh`（`.gitattributes` への行追記処理と、
  `ALWAYS_OVERWRITE_RELPATHS` による `.claude/VERSION` の無条件上書きを追加）。
- 追加: `.claude/scripts/test/test_install_to_project.sh`（配置・`describe` との見出し一致・行追記・
  冪等（LF/CRLF両方）・コメント誤検知・VERSIONの上書きを検証する結合テスト）。
- 更新: `.claude/rules/shell-script-style.md`（`.gitattributes` が「未導入」だった記述）、
  `.claude/rules/markdown-frontmatter.md`（PR/MRテンプレートを「対象外」表へ追加）、
  `.claude/rules/docs-workflow.md`（`reports/` の `.html` が必須なのは flow-id 2-6 だけである旨）、
  `.claude/rules/directory-structure.md` / `index.md` / `README.md` / `DEVELOPERS.md`。

### issue #54（2026-08-22）

- 更新: `### .claude/VERSION` へ、**人間の判断で据え置くことがある**という項と、据え置いた場合の
  実害（版から資産の差を判別できない・改名の後片付けが配布先へ及ばない）を追記した。
  **仕様上の挙動は変更していない**（増分を人間が決める点は元からの規定である）。
- 契機: issue #54 で配布対象アセット（`.claude/skills/issue-mr-flow/assets/` の2ファイル新設と
  `canvas-report/templates/` → `assets/` の改名）が変わったにもかかわらず `0.1.2` を据え置いた。
  その事実は `.claude/docs/spec/issue-mr-workflow.md` のchangelogにしか無く、**規定を持つ本仕様書
  からは例外があったことが見えない**状態だった（フェーズ4の敵対的レビューの指摘）。

### issue #70（`.gemini/` は配布物ではなく配布先で生成する）

`.gemini/` を `.claude/` からの変換生成物へ改めたことに伴い、**配布物からは外した**
（`sync-assets.sh` は `.gemini/` を `assets/` へ集めない）。代わりに `install-to-project.sh` が
配布先で `bash .claude/scripts/src/sync-gemini-assets.sh` を実行して生成する。

- **配布物に含めない理由**: 配布時点の `.claude/` から作った `.gemini/` は、配布先の `.claude/`
  （配布先が独自に足したスキル・hook、Go向けルールの取り回し等）と食い違う。生成スクリプト自体は
  `.claude/scripts/src/` にあるので配布に自動で乗る。
- **生成は Go向けルールの取り回しが終わってから行う。** 先に生成すると、配布先で消したはずの
  ファイルが `.gemini/` 側に残る。
- **生成に失敗しても、インストール全体は中断しない**（警告のみ）。`.gemini/` が無いこと以外の
  インストールは完了しており、中途半端な状態で止めるほうが害が大きいため。とくに配布先が自前の
  `.gemini/` を持っていた場合、生成側の削除ファイル検出が働いて**1バイトも書かずに中断する**ので、
  何も壊さずに警告だけが残る（仕様: [sync-gemini-assets.md](sync-gemini-assets.md)）。
- `jq` が無い環境では `install-to-project.sh` が事前に警告する（`.gemini/` の生成が `jq` に依存する）。

## 未決定事項・懸念点

- **Windows実機（git bash）での改行挙動は未確認**である。issue #33 の作業はLinuxコンテナ上で
  行われ、`.gitattributes` が無い状態でCRLFが混入する事象そのものを再現できなかった。確認できたのは
  「配布経路が `.gitattributes` を運んでいなかったこと」と「行追記で配布先の既存設定が保たれること」
  まで。
- **issue #26（配布方式のmanifest化）への移行時に、この仕様のどこが引き継がれるか。** 現時点の
  対応関係は次のとおりだが、層分け定義そのものは #26 側で決める。

  | 資産 | #26 の層 |
  |---|---|
  | PR/MRテンプレート | `seed`（無ければ配置し、あれば触らない） |
  | `.gitattributes` | `merge`（構造マージ。行追記は #26 が `.gitignore` に定めた規則と同じ） |
  | `.claude/VERSION` | `core`（常に上書き） |

  `.claude/VERSION` と、#26 が予定する `.claude/.asset-manifest.json` は**役割が重複しない**。
  manifestは「適用元コミットSHA＋ファイルごとのsha256」という機械可読で正確な同一性を持ち、
  VERSIONは人間が口頭・issue上で示せる粗い識別子である。
- **`install-to-project.sh` の既存の `.gitignore` 追記処理には、issue #33 で `.gitattributes` 側を
  作るときに避けた問題が残っている。** issue #33 の範囲外として直していないが、issue #26 の
  `merge` 層の設計でまとめて扱うために記録する。
  - 冪等ではない（配列の先頭にある空文字列が毎回無条件に空行を追記するため、再適用のたびに
    空行が1行増える）。
  - 判定が部分一致（`grep -Fq`、`--` 無し）のままで、配布先が `# /.claude/session-logs/ は不要` の
    ようにコメントで言及しているだけでも実設定が入らない。
  - 追記される行（`/.claude/usage-state/` 等4行）が、本家が実際に使う状態ディレクトリ
    （`/usage/` と `/.claude/state/`）と一致していない（issue #23 の一本化に配布側が追従していない）。
- **`HAS_WARNED` が `safe_copy_dir` の外へ伝わらない。** `find ... | while ...` はパイプライン
  なのでサブシェルで実行され、その中で立てた `HAS_WARNED=true` は失われる。結果として、
  `.claude/` `.github/` `.gitlab/` 配下のファイルでどれだけ `.bak` 退避が起きても、
  最後の「ATTENTION: Some existing files differed from the template」ブロックは表示されない
  （個別のWARNING行は出る）。issue #33 の実機確認で判明したが、範囲外として直していない。
- **配布先へ `.gitignore` 対象のローカル生成物が混入する**（`index.jsonl` 10件以上と
  `.claude/state/`）。issue #26 の `local` 層の定義がそのままこの問題を指している。
