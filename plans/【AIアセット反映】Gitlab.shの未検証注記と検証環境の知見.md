# 【AIアセット反映】Gitlab.shの未検証注記と検証環境の知見

対象issue: [#48](https://github.com/yuki-matsu783/MR-driven-workflow/issues/48)
全体作業計画: `plans/mutable-beaming-leaf.md`
先行: `plans/【設計反映】GitLab実機検証結果のspec・DDR反映.md`（**こちらを完了・レビューしてから着手する**）

正史ドキュメント（spec/ddr）への反映は上記の設計反映で扱う。本計画は**AIエージェントの
振る舞いを変えるアセット**（`.claude/scripts/` 内のコメント・`.claude/rules/`・`.claude/skills/`）
のみを対象とする。

## 1. `Gitlab.sh` の `【未検証】` 注記を実態へ更新する（本命）

現在7箇所に「このリポジトリのremoteはGitHubのみのため実機確認できていない」と書かれているが、
**この前提はもう正しくない**。放置すると、後続のAIエージェントが「GitLab側は動かないかもしれない」
という誤った警戒を持ち続ける。

| 行 | 対象 | 対応 |
|---|---|---|
| 10-13 | ファイル冒頭 | 検証済みである旨と、検証条件（GitLab CE 18.5.4 / glab 1.114.0 / self-hosted）・**残る未検証範囲**へ全面的に書き換える |
| 27, 106, 115, 134, 144, 164 | 各関数 | 一律の「未検証」注記を**削除**する。ファイル冒頭に検証状況を集約し、関数ごとの重複をなくす |

冒頭に残す「未検証範囲」は次の3点に限定する。

- `get_provider` がself-hosted URLを判定できない（issue #45、未修正）ため、
  **`Provider.sh` 経由のディスパッチは未検証**。検証は `gitlab_*` を直接呼んで行った。
- 検証したのは **CE 18.5.4 の1バージョン**。gitlab.com（SaaS）・他バージョンは未検証。
- `gitlab_get_repo_url` 等が依存するプロジェクト設定（サブグループ・ネストしたnamespace）は
  単一プロジェクトでしか確認していない。

**注記の書式**: `【未検証】` に対応する `【検証済み】` のような新しい記号は導入しない
（記号を増やすと意味の管理が要る）。散文で書く。

## 2. `.claude/rules/shell-script-style.md` への追記（レビューで**2-1・2-2とも追記すると決定**）

既存の「git bashのパス変換の落とし穴」節・「テスト」節に、今回実際に踏んだものだけを足す。
**踏んでいない一般論は書かない。**

### 2-1. `docker exec` と `MSYS_NO_PATHCONV=1`（**追記する**）

git bashから `docker exec gitlab cat /etc/gitlab/xxx` を実行すると、MSYSが `/etc/...` を
`C:/Program Files/Git/etc/...` へ変換してしまう。既存節は `//in` のような**DOS形式フラグ**の
回避策（先頭 `//`）を書いているが、**コンテナ内の絶対パスを渡すケースは別物**で、
こちらは `export MSYS_NO_PATHCONV=1` が要る。既存節に並べて書く価値がある。

### 2-2. `awk` / `sed` で `\r` を含む行を生成しない（**追記する**）

`awk 'NR==95{print "... tr -d '\''\r'\''"}'` が、文字列リテラルの `\r` を**CR文字そのものへ展開**し、
ソースへ生のCRバイトを混入させた（`tr -d ''` に見える行が出来た）。
既存の「文字コード」節はjq出力のCRを扱っているが、**自分で書くコード生成側**の話は無い。
対策（クォート済みヒアドキュメントで1行を書き出し `sed` で前後を連結する）まで含めて書く。

### 2-3. 追記しないと判断したもの

| 内容 | 理由 |
|---|---|
| GitLabのPATが `glpat-<38>.<2>.<9>` 形式（ドットを含む） | bashスクリプトの規約ではない。トークン抽出の正規表現を誤った話であり、`shell-script-style.md` の主題から外れる。**恒久ルールにせず本issueのworklog止まりにする** |
| glabがlocalhostをIPv6で解決して接続リセット | 同上。検証環境固有 |
| git credential helper のチェーンを空文字で切る | 検証環境構築の手順であり、リポジトリの開発規約ではない |

**レビュー結果（flow-id 4-3〜4-4）**: 2-1・2-2とも追記することで合意した。
「一度きりの作業で踏んだ知見だが、次に同じ環境へ触る担当者が同じ罠を踏む」という性質を重視した。

## 3. `.claude/rules/docs-workflow.md` の記述矛盾（レビューで**別issueへ切り出すと決定**）

ドキュメント運用表の `worklog/` 行に「PR作成前の設計反映でまとめて削除」とあるが、
`.claude/skills/issue-mr-flow/SKILL.md` の全体フローでは削除は **flow-id 5-1**（フェーズ5）であり、
設計反映（flow-id 4-6）ではない。`reports/` 行も同じ記述になっている。

本issueの作業中に、どちらに従うべきか実際に迷った。SKILL.md が「唯一の実装フロー定義」である以上、
`docs-workflow.md` 側を **flow-id 5-1 に合わせて修正する**のが筋と考える。

**レビュー結果（flow-id 4-3〜4-4）**: 別issueとして切り出すことで合意した。
**issue [#51](https://github.com/yuki-matsu783/MR-driven-workflow/issues/51) として起票済み。**
`docs-workflow.md` の修正そのものは本MRに含めない。

## 4. 反映しないと判断したもの

| 内容 | 理由 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 今回のフロー運用で不備は見つからなかった。レビュー完了合図の確認（`comments all`）も想定どおり機能した |
| `CLAUDE.md` / `AGENTS.md` | 変更の必要なし |
| ローカルGitLab構築手順のスクリプト化 | scratchpadに残した `run-gitlab.sh` 等をリポジトリへ入れる案もあるが、**issue #45 が未修正のうちは再検証の需要が読めない**。issue #45 対応時に必要になったらそこで判断する |

## 作業手順

1. `Gitlab.sh` の注記を更新する（1.）。
2. レビューで合意が取れた範囲で `shell-script-style.md` へ追記する（2.）。
3. `docs-workflow.md` の矛盾（3.）は issue #51 として起票済み。本MRでは修正しない。
4. worklog へ反映内容を追記する。

## 検証方法

- `bash -n .claude/scripts/src/vcs/Gitlab.sh` が通ること（コメントのみの変更だが機械的に確認する）。
- `bash tests/test_vcs_provider.sh` が `passed=11 failures=0` のままであること。
- `grep -c '【未検証】' .claude/scripts/src/vcs/Gitlab.sh` が想定どおりの件数（冒頭のみ、または0）になること。
- **`Gitlab.sh` の実行可能コードに差分が出ていないこと**を `git diff` で確認する
  （本計画はコメントのみを対象とする）。
