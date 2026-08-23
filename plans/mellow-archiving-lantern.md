---
title: MR/PRテンプレートをアーカイブとして再設計する（全体作業計画）
type: plan
description: issue #145 の全体作業計画。MR/PRテンプレートの見出しを10節構成へ改め、describe節との二重管理を解消する
tags: [plan, issue-mr-flow, template]
keywords: [PRテンプレート, MRテンプレート, describe, アーカイブ, 二重管理, 統括レポート, 見出し構成, plans参照禁止]
---

# MR/PRテンプレートをアーカイブとして再設計する（全体作業計画）

issue #145 / PR #187 / ブランチ `claude/mr-pr-template-archive-0bo17a`

## この計画で何をするか

MR/PRのdescriptionを、レビュー時だけの作業メモではなく「**後からこのPRを開いた人が、何を・なぜ・
どうやったかを一望できるアーカイブ**」として機能させる。具体的には次の3つを行う。

1. `.github/pull_request_template.md` と `.gitlab/merge_request_templates/Default.md` の見出しを、
   issue #145「期待する動作」が定める10節構成へ改める（GitHub版・GitLab版で同一）。
2. `describe` サブコマンド（`.claude/skills/issue-mr-flow/references/review-loop.md`）が生成する
   descriptionを同じ構成に合わせ、各見出しに「計画段階では何を書くか」を定める。
3. テンプレートファイルと `describe` 節に同じ雛形が二重に存在している状態を解消する。

## なぜやるか

- `plans/` `worklog/` `reports/` は flow-id 5-5 で削除され、squash mergeによりmainにも残らない。
  spec/DDRへ昇格しなかった経緯・却下案・検証結果の**唯一の恒久的な置き場がPR/MRのページ**である。
- ところが現行テンプレートは `Closes #N` / `## Plan` / `## 実装状況` の3点しか持たず、
  過去64件のPRのうち約3分の2が独自構成へ流れている（issue #145「現状」の集計）。
- さらに64件中52件が本文から `plans/` `worklog/` `reports/` を参照しており、削除後は参照先が無い。
  `.claude/rules/docs-workflow.md` はコード・スクリプト内のコメントからの参照を禁じているが、
  **MR本文には同じ歯止めが無い**。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.github/pull_request_template.md` | 変更 | 見出しを10節構成へ差し替え、各節にHTMLコメントで「何を書くか／計画段階では何を書くか」を置く |
| `.gitlab/merge_request_templates/Default.md` | 変更 | 同上（GitHub版と同一の見出し構成） |
| `.claude/skills/issue-mr-flow/references/review-loop.md` | 変更 | `describe` 節の雛形を、二重管理の解消方針（フェーズ2の結論）に沿って書き換える |
| `.claude/rules/docs-workflow.md` | 変更 | MR/PR本文からの `plans/` `worklog/` `reports/` 参照禁止を明記する |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | テンプレートの位置づけ・二重管理の解消方式・#111 との役割分担を仕様として記録する |
| `.claude/docs/ddr/i0145-*.md` | 新規 | 二重管理の解消方式と、#111（統括レポート）との役割分担の判断を記録する |
| `.claude/docs/usecase/*.md` | 変更（要確認） | MR descriptionに触れるユースケース文書があれば更新する |

## 方針

- **見出し構成はissue #145「期待する動作」の10節をそのまま採る。** 順序も含めて指定されており、
  この計画で組み替えない。
- **固定見出しは、該当が無ければ「特になし」と1行書いて残す。節ごと削除してよいのは `## 備考` のみ。**
  消すと「検討した結果無かった」のか「書き忘れ」なのかを後から読む人が区別できないため。
- **二重管理の解消方式は、フェーズ2の調査で決める。** issue本文が挙げる「`describe` の手順を
  テンプレートファイルの読み込みへ変えて一本化する案」を含めて比較し、DDRへ残す。
  この全体作業計画の時点では結論を書かない。
- **#111（最終統括レポートのサマリコメント）との役割分担も、フェーズ2で決める。** #111 は
  PR #144 で既にマージ済み（flow-id 5-4 として稼働している）ため、廃止ではなく棲み分けの定義になる。

## フェーズ2〈調査〉

次の問いに答える。答えが出れば個別作業計画（flow-id 3-1）を書ける。

1. **二重管理をどう解消するか。** `describe` がテンプレートファイルを読み込む方式は、
   (a) 非対話環境・MCP経路でも動くか、(b) 配布先（`apply-mr-workflow-to-project`）で
   テンプレートがどの層に属するか、(c) テンプレートが配布先で改変されている場合に何が起きるか。
2. **#111 との役割分担。** flow-id 5-4 の統括レポート／サマリコメントと、MR descriptionは
   それぞれ何を担うのか。重複させるのか、片方へ寄せるのか。
3. **`plans/` 参照禁止をどこにどう書くか。** テンプレート側（HTMLコメント）と
   `.claude/rules/docs-workflow.md` の双方に必要だが、既存の「コード・スクリプト内のコメントから
   参照しない」という記述との関係をどう書くか。
4. **10節構成が `describe` の6回の全文置換と噛み合うか。** flow-id 2-5/2-10/3-5/3-10/4-5/4-10 の
   各時点で、まだ書けない節（例: `## レビューの結果`）をどう扱うか。
5. **配布物としての影響。** `.claude/dist-layers.json` におけるテンプレート2本の層と、
   `.gemini/` への変換同期（flow-id 5-3）の対象になるか。

## フェーズ3〈作業〉

フェーズ2の結論をもとに、テンプレート2本と `describe` 節・関連ルールを実装する。
このPR自身のdescriptionを新テンプレートで書く（issue #145 の受け入れ条件のドッグフーディング）。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- `.claude/docs/spec/issue-mr-workflow.md` — テンプレートの位置づけ・#111 との役割分担
- `.claude/docs/ddr/i0145-01-*.md` — 二重管理の解消方式の判断と却下案
- `.claude/docs/ddr/i0145-02-*.md` — #111 との役割分担の判断（1件にまとまるなら01へ含める）
- `.claude/docs/usecase/` — MR descriptionに触れる記述があれば更新
- issue #111 への通知（受け入れ条件。flow-id 5-2 で行う）

## やらないこと（スコープ外）

- **flow-id 5-4（統括レポート）の仕組みそのものの変更。** 役割分担の定義は行うが、
  #111 で作った実装（`upload_attachment`・3層フォールバック）には手を入れない。
  変更が必要だと分かった場合は別issueへ切り出す。
- **過去64件のPR本文の遡及修正。** 新テンプレートは今後のPRへ適用する。
- **issueテンプレート（`.github/ISSUE_TEMPLATE/` `.gitlab/issue_templates/`）の変更。**
  本issueの対象はPR/MRテンプレートのみ。
- **`describe` 以外のサブコマンドの仕様変更。**

## 検証

```bash
# テンプレート2本の見出しが完全に一致すること
diff <(grep -E '^## ' .github/pull_request_template.md) \
     <(grep -E '^## ' .gitlab/merge_request_templates/Default.md)

# frontmatterインデックスの再生成が通ること
bash .claude/scripts/src/extract-frontmatter.sh .

# DDRを追加した場合、一覧が生成物と一致すること
bash .claude/scripts/src/generate-ddr-list.sh

# ドキュメント参照が切れていないこと
bash .claude/scripts/src/check-doc-references.sh

# .gemini/ への変換同期に差分が残っていないこと（flow-id 5-3）
bash .claude/scripts/src/sync-gemini-assets.sh --check
```

合格条件: 上記がすべて成功し、issue #145 の受け入れ条件9項目すべてに対応箇所があること。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応するフェーズ |
|---|---|
| GitHub版とGitLab版が同一の見出し構成 | フェーズ3 |
| 設計判断／やらなかったこと／未解決／レビューの結果 の4項目が固定見出し | フェーズ3 |
| `## 備考` が唯一の削除可能見出しである旨の明記 | フェーズ3 |
| 各見出しに「何を書くか」「計画段階では何を書くか」をHTMLコメントで | フェーズ3 |
| `plans/` 等の参照禁止をテンプレートと `docs-workflow.md` の双方へ明記 | フェーズ3（ルール側はフェーズ4でも可） |
| `describe` 節が新しい見出し構成と一致 | フェーズ3 |
| 二重管理の扱いの判断がspecまたはDDRに記録されている | フェーズ2で判断 → フェーズ4で記録 |
| #111 との役割分担の判断が記録され、#111 へ通知されている | フェーズ2で判断 → フェーズ4で記録 → flow-id 5-2 で通知 |
| 本issueのPR自身が新テンプレートで書かれている | フェーズ3以降の `describe` |
