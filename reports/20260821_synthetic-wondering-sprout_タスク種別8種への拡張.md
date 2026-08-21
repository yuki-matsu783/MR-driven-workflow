---
title: タスク種別を6種から8種へ拡張した作業結果
type: report
description: issue #110 個別計画のタスク種別に【AIアセット作成】【実装反映】を追加した作業結果
tags: [issue-mr-flow, タスク種別, docs]
keywords: [タスク種別, AIアセット作成, 実装反映, SKILL.md, docs-workflow, REVIEW-POINTS, issue-mr-workflow]
---

# タスク種別を6種から8種へ拡張した作業結果

対象issue: #110　個別計画（フェーズ2〜4で作る`plans/【*.md`）で使うタスク種別に
関連: `plans/synthetic-wondering-sprout.md`（全体作業計画）、
`plans/【設計】タスク種別8種への拡張.md`（個別作業計画）

## 何をしたか

個別計画のタスク種別を6種から8種へ拡張し、`【AIアセット作成】`（フェーズ3〈作業〉）・
`【実装反映】`（フェーズ4〈反映〉）を新設した。この種別を重複記載していた4ファイルすべてを
更新した。

| ファイル | 変更内容 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 種別6種の列挙を8種へ拡張し、各種別が属するフェーズの一覧表を新設。併記/分割の指針（`【設計反映】`/`【AIアセット反映】`は併記しない）を`【実装反映】`まで含めて拡張し、`【AIアセット作成】`の併記/分割基準も明記 |
| `.claude/docs/spec/issue-mr-workflow.md` | 「計画の2階層構造」節の「6種」記述を8種へ更新し、詳細をSKILL.md側へ委譲 |
| `.claude/rules/docs-workflow.md` | ライフサイクル表の`plans/【種別】タスク内容.md`行の種別列挙を8種へ更新 |
| `plans/REVIEW-POINTS.md` | 「種別」節を8種へ更新し、新種別の使い分け（`【AIアセット作成】`/`【AIアセット反映】`が成果物か副産物か、`【実装反映】`がフェーズ3のループと役割重複していないか）をレビュー観点として追加 |

## 新種別の定義（確定内容）

Planレビューで`【実装反映】`の使いどころについて2段階の議論があった（詳細:
`plans/synthetic-wondering-sprout.md`「『実装反映』の使いどころ」節）。最終的にissue本文どおり、
次の定義に確定した。

- **`【AIアセット作成】`（フェーズ3〈作業〉）**: そのissueの主たる成果物としてAIアセット
  （スキル・ルール・エージェント・スクリプト）を作る作業。副産物としての改善を反映する
  `【AIアセット反映】`（フェーズ4）とは、成果物か副産物かで使い分ける。
- **`【実装反映】`（フェーズ4〈反映〉）**: フェーズ3（とくに`【テスト】`）で失敗・不具合が
  判明した場合に、フェーズ4でその内容を記録へ書き戻しつつ、実装コード・テストコードの修正も
  あわせて行う種別。`【設計反映】`（spec/ddrへの書き戻しのみ）と対になる。フェーズ3の
  レビュー往復ループ（3-6〜3-9）で解消できる不具合はそちらで対応し、フェーズ4へは持ち越さない。

## なぜそうしたか

- **`【AIアセット作成】`が無かった理由**: `【実装】`は実装コードを指すため、AIアセット
  （非コードの運用資産）の作成には合わない。
- **`【実装反映】`が無かった理由**: `【設計反映】`はspec/ddr、`【AIアセット反映】`は
  `.claude/rules/`等が対象で、実装コードの更新を扱う種別が無かった。
- **却下した代替案**（DDRへ記録予定。flow-id 4-6）:
  - 既存種別（`【実装】`・`【AIアセット反映】`）を流用する案 → 対象・成果物か副産物かの
    区別が曖昧になるため却下。
  - 種別を増やさずfree-textで書く案 → 機械的な列挙（`plans/【*.md`）・レビュー観点表との
    整合が取れなくなるため却下。
  - `【実装反映】`を「フェーズ4の設計反映作業中にAIが気づいた実装との差分」に限定する案 →
    「反映計画では立てられない役割で、起きたら別issueで書く内容」としてPlanレビューで
    却下（詳細は全体作業計画を参照）。

## 検証結果

```
$ grep -rln "6種" .claude plans --include="*.md"
.claude/docs/ddr/i0009-01-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md
plans/synthetic-wondering-sprout.md
plans/【設計】タスク種別8種への拡張.md
plans/REVIEW-POINTS.md（本作業のreports/plansファイル自体の言及。対象4ファイルには残存なし）
```

対象4ファイル（`SKILL.md` / `issue-mr-workflow.md` / `docs-workflow.md` / `REVIEW-POINTS.md`）の
いずれにも「6種」の残存は無く、「6種から拡張」という経緯を示す注記としてのみ残る（SKILL.md
153行、issue-mr-workflow.md 247行）。`i0009-01`のDDR本文は過去の意思決定記録のため変更していない
（DDR本文は一度マージしたら変更しない運用。`.claude/rules/markdown-frontmatter.md`）。

```
$ grep -rn "AIアセット作成\|実装反映" .claude/skills/issue-mr-flow/SKILL.md \
  .claude/docs/spec/issue-mr-workflow.md .claude/rules/docs-workflow.md plans/REVIEW-POINTS.md
```
上記4ファイルすべてで新種別への言及を確認済み（詳細は各ファイルの差分を参照）。

## 受け入れ条件との対応

- [x] `.claude/skills/issue-mr-flow/SKILL.md` の種別一覧が8種になり、各種別の属するフェーズと、
      `【AIアセット作成】`/`【AIアセット反映】`・`【実装反映】`/`【設計反映】` の使い分けが
      読み取れる
- [x] `.claude/docs/spec/issue-mr-workflow.md` の「6種」の記述が8種へ更新されている
- [x] `.claude/rules/docs-workflow.md` のライフサイクル表の種別欄が8種になっている
- [x] `plans/REVIEW-POINTS.md` のレビュー観点が8種になっている
- [x] 併記/分割の指針（`【設計反映】` と `【AIアセット反映】` は原則分ける）と、新種別との関係が
      整理されている
- [x] フェーズ構造（5フェーズ・flow-id）に変更が入っていない（`.claude/skills/issue-mr-flow/
      SKILL.md`の全体フロー表・flow-id割り当ては未変更。差分は種別の列挙・説明文のみ）
- [ ] 2種別を追加した経緯とフェーズ割り当ての根拠がDDRに記録されている（**flow-id 4-6で対応
      予定**。本reportsは作業結果、DDR新設は反映フェーズの担当）

## 残課題

- DDR（`.claude/docs/ddr/i0110-01-…md`）の新設と`.claude/docs/README.md`一覧の再生成は
  flow-id 4-6（フェーズ4〈反映〉）で行う。
