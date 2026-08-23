---
title: 配布テンプレート資産（PR/MRテンプレート・.gitattributes・VERSION）
type: spec
description: 他プロジェクトへ配布するテンプレート資産の内容と、配布経路上での扱いの仕様
tags: [spec, distribution, template]
keywords: [pull_request_template, merge_request_templates, gitattributes, VERSION, dist-layers, asset-manifest, install-to-project, 行追記, 冪等, 版管理]
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

`install-to-project.sh` はマーカーの間の行（コメント・空行を除く）だけを読んで配布先へ追記する
（`.gitattributes` は `merge` 層の `lines-marker` 戦略で扱われる。仕様:
[asset-distribution.md](asset-distribution.md)）。
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

**issue #26 で、配布は「本家 → `assets/`（中間生成物）→ 配布先」の2スクリプト方式をやめ、
本家の実状態を直接読む1スクリプト（`install-to-project.sh`）へ変わった。** どのパスをどう扱うかは
`.claude/dist-layers.json` が層として定義し、本仕様書はそこで**3資産に割り当てられた層**を示す
（層そのものの定義・インストーラの動作は [asset-distribution.md](asset-distribution.md) が正）。

| 資産 | 層 | 配布先の既存ファイルの扱い |
|---|---|---|
| PR/MRテンプレート（`.github/` `.gitlab/`） | **`core`** | 常に上書き。配布先で改変されていれば `.bak` へ退避してから上書きし、一覧で知らせる |
| `.claude/VERSION` | **`core`**（`.claude` エントリに含まれる） | 同上 |
| `.gitattributes` | **`merge`（`lines-marker`）** | **上書きしない。** マーカー間の行が無ければ足すだけ |

- **`.claude/VERSION` に専用の例外（旧 `ALWAYS_OVERWRITE_RELPATHS`）は要らなくなった。**
  旧方式は「配布先のファイルが本家と1バイトでも違えば改変とみなす」判定だったため、**版を上げた回は
  必ず**警告と `.bak` が出ていた。新方式は manifest に記録した「前回適用したときのsha256」と比べる
  ため、配布先が触っていなければ改変とはみなさず、警告も `.bak` も出ない。**上流の変更と配布先の
  改変を区別できるようになったことで、例外指定そのものが不要になった**（`.claude/VERSION` は
  `.claude` エントリの `core` として、他のファイルと同じ扱いで配られる）。
- **PR/MRテンプレートは `seed` ではなく `core` である。** 見出し構成は `describe` が生成する
  descriptionと一致していなければならず（上記「PR/MRテンプレート」節）、配布先が独自に書き換える
  ことを想定しない。配布先が実際に書き換えていれば、`.bak` 退避と一覧で気づける。

`.gitattributes` の行追記（`merge` / `lines-marker`）には次の性質がある（
[DDR i0033-03](../ddr/i0033-03-gitattributesは配布先へ丸ごとコピーせず必要な行だけ追記する.md)。
**同DDRの本文は当時の実装名（`ensure_gitattributes_rules`）で書かれているが、それは
point-in-time の記録であり、現在の実装は `merge` 層の `lines-marker` 戦略である**）。

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

### issue #26（2026-08-23）

配布方式を manifest 方式へ作り直したことに伴う更新。**機構そのものの仕様は
[asset-distribution.md](asset-distribution.md) を新設して移した**ので、本仕様書は
「配る**資産**の側」に絞られた。

- 更新: `### 配布経路での扱い` を**層ベースへ全面書き換え**した。3資産の層は
  PR/MRテンプレート＝`core` / `.claude/VERSION`＝`core` / `.gitattributes`＝`merge`（`lines-marker`）。
- 削除: `sync-assets.sh` `safe_copy_dir` `ALWAYS_OVERWRITE_RELPATHS` `ensure_gitattributes_rules`
  への言及（いずれも issue #26 で無くなった）。**過去のchangelogエントリ（issue #33 / #54）に
  出てくる同じ語は、当時の事実として残す。**
- **`.claude/VERSION` は `0.2.0` のまま据え置いた。** 上記「人間の判断で据え置くことがある」の
  規定に従い、据え置いた事実をここへ残す。
  - 経緯: AIエージェントは `1.0.0`（`MAJOR`）を提案した。根拠は、旧方式で配られた `AGENTS.md` が
    `requiredLine` による一覧提示だけでは自動で直らず、**配布先に手作業での移行を要求する**ため
    である。**この提案は採用されず、flow-id 4-4 のレビューで `0.2.0` 据え置きと決まった**
    （増分を決めるのは人間、という規定どおりの結果）。
  - **実害を承知のうえでの判断である。** 配布先は同じ `0.2.0` のまま、**配布の仕組みごと入れ替わった**
    `.claude/` を受け取る。版から資産の差を判別できないという実害は、過去のどの据え置きよりも大きい。
    ただし issue #26 で `.claude/.asset-manifest.json` が入ったため、**機械可読な同一性は
    manifest 側（`source.commit` ＋ ファイルごとの sha256）で判別できる**。VERSIONだけが
    手掛かりだった issue #54 の据え置きとは、この点が異なる。
- 解消: 下記「未決定事項・懸念点」のうち**4項目を削除**した。解消先は次のとおり。

  | 削除した項目 | どこで解消したか |
  |---|---|
  | issue #26 への移行時にどこが引き継がれるか（層の対応表） | 上記「配布経路での扱い」の表が正になった。**旧表の「PR/MRテンプレート＝`seed`」は見込みであり、実装は `core` である** |
  | `.gitignore` 追記処理の3つの問題（非冪等・部分一致・行の不一致） | `merge` / `lines-marker` として作り直して解消（`.gitignore` の配る行も `dist:begin`〜`dist:end` のマーカーで定義するようになった） |
  | `HAS_WARNED` が `safe_copy_dir` の外へ伝わらない | `safe_copy_dir` ごと廃止。新実装は走査（1パス目）で件数を集計してから提示するため、サブシェルを跨ぐ状態受け渡しが無い |
  | 配布先へ `.gitignore` 対象のローカル生成物が混入する | `local` 層（17エントリ）で解消 |
- **`.gemini/` の扱いは issue #70 側が正である**（上のエントリ）。issue #26 は `sync-assets.sh` を
  廃止したため、issue #70 のエントリにある「`sync-assets.sh` は `.gemini/` を `assets/` へ集めない」
  という記述は**当時の実装を指す point-in-time の記録**として読むこと。現在は中間生成物 `assets/`
  そのものが無く、`.gemini/` は層分け定義で `local`（配らない）として明示されている。
  配布先での生成を `install-to-project.sh` が行う点は変わらない。

## 未決定事項・懸念点

- **Windows実機（git bash）での改行挙動は未確認**である。issue #33 の作業はLinuxコンテナ上で
  行われ、`.gitattributes` が無い状態でCRLFが混入する事象そのものを再現できなかった。確認できたのは
  「配布経路が `.gitattributes` を運んでいなかったこと」と「行追記で配布先の既存設定が保たれること」
  まで。**issue #26 でもこの状況は変わっていない**（同じくLinux上での作業だった）。
  配布機構の側にもWindows実機でしか確認できない項目が3件あり、そちらは
  [asset-distribution.md](asset-distribution.md)「未決定事項・懸念点」がまとめて持つ。
- **`.claude/VERSION` と `.claude/.asset-manifest.json` は役割が重複しない。** manifestは
  「適用元コミットSHA＋ファイルごとのsha256」という機械可読で正確な同一性を持ち、VERSIONは
  人間が口頭・issue上で示せる粗い識別子である。**両方を持ち続けるかどうかは決めていない**
  （issue #26 では VERSION を廃止せず据え置いた）。manifestがある以上VERSIONは要らない、
  という判断はありうるが、その場合は「配布先の人間がどう版を口にするか」の代替が要る。

**issue #26 で解消した4項目は削除した**（削除の理由と解消先は上記
「影響範囲 > issue #26（2026-08-23）」に残してある）。
