# 【設計反映】GitLab実機検証結果のspec・DDR反映

対象issue: [#48](https://github.com/yuki-matsu783/MR-driven-workflow/issues/48)
全体作業計画: `plans/mutable-beaming-leaf.md`
先行フェーズ: `plans/【実装】【テスト】Gitlab.shの3件の不具合修正.md`（フェーズ3完了）

`plans/` `worklog/` に残した内容のうち、**正史として永続させるべきもの**を
`.claude/docs/spec/` `.claude/docs/ddr/` へ反映する。運用ルール（`.claude/rules/`・
`.claude/skills/`）への反映は `plans/【AIアセット反映】...md` で別途扱う。

## 反映の骨子

フェーズ3で得られた「正史に載せるべき事実」は次の3つ。

1. **`glab mr create` は差分ゼロでも成功する**（GitLab CE 18.5.4 実測）。空コミット
   フォールバックが必要なのは `gh pr create`（GitHub）側だった。
2. **GitLabのdiscussions APIはシステムノートを同じ配列で返す**。レビューコメントとして
   混入させないため `system` による除外が必須である。
3. **`Gitlab.sh` は実機検証済みになった**。spec全体に散らばる「GitLab側の動作未検証」という
   前提が、部分的に解消された。

## 1. `.claude/docs/spec/issue-mr-workflow.md`

### 1-1. 「### Draft PR作成失敗時の自動リトライ」節（L259-265）を訂正する

**現在の状態を説明する節**のため書き換えてよい（`.claude/rules/docs-workflow.md`）。

現状の記述は「`gh pr create` / `glab mr create` が失敗する既知の制約があった」と**両プロバイダを
並べて**いるが、これは誤り。以下へ改める。

- 差分ゼロで失敗するのは **GitHub固有**であること（issue #48で両者を同一セッション内で実測）。
- GitLab CE 18.5.4 では差分ゼロのブランチでもMR作成に成功し、フォールバックに到達しないこと。
- それでも分岐を残しているのは、検証できたのが18.5.4の1バージョンのみだからであること。
- DDR 0005 へのリンクはそのまま維持する。

### 1-2. 「### 提供関数」表に `gitlab_format_discussion_notes` を追記する

③で純粋関数を切り出したため、コンポーネント構成・提供関数の記述と実装がずれている。
`Provider.sh` 経由で公開するディスパッチャではなく `Gitlab.sh` 内部のヘルパーである点を明記する。

### 1-3. 「## 未決定事項・懸念点」の「GitLab側の動作未検証」（L1278-1281）を解消する

`.claude/rules/docs-workflow.md` は「`spec` の未決定事項が解消したら記録し、spec側の該当項目は
削除してよい」としている。今回は**全面解消ではない**ため、削除ではなく次のように書き換える。

- **解消した範囲**: `Gitlab.sh` の全13関数をローカルGitLab CE 18.5.4で実機確認した。
- **残る範囲**: (a) `get_provider` がself-hosted GitLabを判定できない（issue #45、未修正）ため
  Provider.sh経由のディスパッチは未検証、(b) 検証したのは18.5.4の1バージョンかつCE・
  シングルプロジェクトのみ、(c) gitlab.com（SaaS）では未検証。

あわせて L1395-1397 の「issue #25で追加した `gitlab_new_issue` にも従来からの制約が引き継がれる」
も、`gitlab_new_issue` は実機確認済みになったため同様に更新する。

L1273-1277（issue #13のURL形式がブラウザ未検証）については、**今回ブラウザでの表示確認までは
行っていない**ため触らない（実機で叩いたのはAPIであり、Compare URLの表示確認は別物）。

### 1-4. 「## 決定済み事項（旧・未決定事項）」へ追記する

「未解決コメントの判定基準」の項が既にあるが、`system` ノートの扱いが書かれていない。
「GitLabは `resolvable`/`resolved` に加えて `system` による除外が必要」である旨を追記する。

### 1-5. 「## 影響範囲」へ**新規エントリを追記**する

既存の `変更（追加分・issue #NN ...）:` 形式に倣い、issue #48分のブロックを末尾へ足す。

**過去のissueごとのchangelogエントリは書き換えない**（`.claude/rules/docs-workflow.md`。
point-in-timeの記録のため）。特に issue #13・#15・#25 のエントリ内にある `Gitlab.sh` への
言及は、当時の記述のまま残す。

## 2. `.claude/docs/ddr/`

### 2-1. DDR 0005 は本文・frontmatterとも変更しない

GitHubについては決定内容が現在も有効であり、`superseded` にも `deprecated` にも当たらない
（全体作業計画で合意済みの制約）。

### 2-2. DDR 0026 を新規作成する（**要判断**）

タイトル案: `0026-空コミットフォールバックはGitHub固有の制約として残す.md`

- **決定**: GitLabでは到達しないと実測できたが、`gitlab_new_draft_merge_request` の
  フォールバック分岐は削除せず残す。
- **却下案**: (a) GitLab側の分岐を削除する（→ 18.5.4以外での挙動を保証できない）、
  (b) `get_provider` の結果で分岐を出し分ける（→ 実害の無い安全網のために複雑さを増やす）。
- DDR 0005 を**置き換えるものではない**ため `superseded_by` は付けない（0005の決定は
  GitHubについて有効なまま。0026は適用範囲を限定する追記的な決定）。

**判断が必要な点**: これをDDRとして独立させるか、spec 1-1の記述だけで足りるとみなすか。
DDRは「〇〇を検討したが✕✕を採用した」を残す場所であり、「削除も検討したが残した」は
その形に合致する。**独立させる案を推すが、レビューで却下されれば 1-1 の記述のみに留める。**

### 2-3. `.claude/docs/README.md` のDDR一覧へ 0026 を追記する（2-2を採用する場合のみ）

## 3. 反映しないと判断したもの

| 内容 | 理由 |
|---|---|
| ローカルGitLab構築手順（Docker・PAT発行・glab認証） | 「issue駆動MRワークフロー機構の仕様」ではなく検証環境の作り方。specの主題から外れる。`【AIアセット反映】`側で扱うか判断する |
| jq出力のCR除去 | 既存ルール（`shell-script-style.md`「文字コード」）に既に書かれている事象の一適用例にすぎず、新しい設計判断ではない。影響範囲エントリでの言及に留める |
| glabのIPv6接続リセット | 検証環境固有の一過性事象。worklogに残っていれば十分 |
| `to_slug` が日本語タイトルを潰す挙動 | GitHub側と共通でGitLab固有ではない。本issueの範囲外（未起票のまま `HANDOFF.md` の未解決欄に残す） |

## 作業手順

1. spec の 1-1〜1-4 を編集する（1-5 の影響範囲エントリは最後にまとめて書く）。
2. 2-2 のDDRを新規作成し、`.claude/docs/README.md` へ追記する。
3. 1-5 の影響範囲エントリを、実際に変更したファイル一覧をもとに書く。
4. `bash .claude/scripts/src/extract-frontmatter.sh .` は**実行不要**（`index.jsonl` は生成物で
   SessionStart hookが再生成する。issue #36）。新規DDRのfrontmatterは規約どおり付ける。
5. worklog へ反映内容を追記する。

## 検証方法

- 過去のchangelogエントリ（issue #13/#15/#23/#25 の各ブロック）が**1文字も変わっていない**ことを
  `git diff` で確認する。
- DDR 0005 のファイルが `git status` に現れないことを確認する。
- 新規DDRのfrontmatterが `.claude/rules/markdown-frontmatter.md` の規約（`title`/`type: ddr`/
  `description`/`tags`/`keywords`）を満たすことを確認する。

## この計画で削除するもの

**まだ削除しない。** `worklog/` `plans/` の削除はflow-id 5-1で行う
（`.claude/rules/docs-workflow.md` の表では worklog は「PR作成前の設計反映でまとめて削除」と
あるが、本リポジトリの全体フローでは 5-1 に集約されている）。
