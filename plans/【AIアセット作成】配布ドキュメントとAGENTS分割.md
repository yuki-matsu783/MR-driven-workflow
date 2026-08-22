---
title: 配布ドキュメントの書き換えとAGENTS.mdの分割（issue #26）
type: plan
description: AGENTS.mdの共通ルール切り出し・CLAUDE.md/GEMINI.mdのポインタ化・apply-mr-workflow-to-projectのSKILL.md全面改訂・DEVELOPERS.mdの書き換えを行う個別作業計画
tags: [plan, ai-asset, distribution, documentation]
keywords: [AGENTS, agent-common, CLAUDE, GEMINI, SKILL, DEVELOPERS, skill-package, seed, 雛形, build]
---

# 【AIアセット作成】配布ドキュメントとAGENTS分割

- issue: #26 / PR: #154 / フェーズ: 3〈作業〉（flow-id 3-1）
- 全体作業計画: `plans/ai-asset-manifest-distribution.md`
- 調査結果（この計画の入力）: `reports/20260822_ai-asset-manifest-distribution_配布アセットの層分け調査.md`
- 対になる計画: `plans/【設計】【実装】【テスト】manifest方式の配布機構.md`

**この計画には実施結果を書かない**（結果は `reports/…md` へ。issue #87）。

## この計画の範囲

配布機構の**読み物**（AIアセットとしてのルール・スキル定義・開発者向けガイド）を作る。
定義ファイル・スクリプト・テストは対の計画が担当する。

`【AIアセット作成】` を対の計画から**分けた**のは、合意の単位が違うためである。こちらは
「AIエージェントが何を読むか」「配布先が何を書き足すか」という**運用の取り決め**で、
対の計画は「機構が正しく動くか」である。前者だけ差し戻したい／先に合意したい場面が想定される。

### この計画で決めないこと（スコープ外）

| 事項 | どこで決めるか |
|---|---|
| 層分け定義ファイル・manifest・インストーラ・テスト | 対の `【設計】【実装】【テスト】` |
| `.claude/docs/spec/distribution-assets.md` の更新、新方式のspec、方式選定のDDR（受け入れ条件11） | **フェーズ4**（flow-id 4-1 で洗い出す） |
| `.claude/docs/spec/adversarial-review.md` の `REVIEW-POINTS.local.md` 追記 | フェーズ4（specのため） |
| `.claude/VERSION` を上げるかどうか | フェーズ4 |
| 収穫（逆輸入）スキル | **本issueの範囲外**（後続issue） |

## 前提（確定済み。いつ決まったか）

| # | 前提 | 決まった場所 |
|---|---|---|
| 1 | `AGENTS.md`「ルール」節の**9項目すべてが本家所有** | flow-id 2-6 の調査6 |
| 2 | 切り出し先は `.claude/rules/agent-common.md`。`AGENTS.md` は `seed` になる | 同上 |
| 3 | `CLAUDE.md` / `GEMINI.md` は **`core`**。空の「固有ルール」見出しはポインタへ差し替える（セットで必須） | ユーザー判断（flow-id 2-9 でMRへ記録済み） |
| 4 | `.claude/rules/*.md` は Claude Code ではセッション開始時に自動で読み込まれる（`alwaysApply` に依存しない） | flow-id 2-6 の調査6（実測） |
| 5 | Gemini CLI 側の挙動と `@` import の解決基準は**未確認**。安全側に倒し `AGENTS.md` からの import も併せて張る | 同上 |
| 6 | `.skill` パッケージ手順の廃止で書き換えるのは6ファイル、**触ってはいけない**のは6箇所 | flow-id 2-6 の調査7 |

---

## 作業1: `AGENTS.md` の分割（受け入れ条件9）

### 切り出し

- 新規 `.claude/rules/agent-common.md`（`type: rule`、`title: AIエージェント共通ルール`）。
- 中身は現行 `AGENTS.md`「## ルール」節の**9項目をそのまま移す**。
  **文面を書き直さない**（この作業は移動であり改訂ではない。同時に書き換えると、レビューで
  「移動したのか変わったのか」が読めなくなる）。
- 項目9（ドキュメント探索は frontmatterインデックス検索を第一手段にする）は「ルール」節で最も
  長い項目で、**落とすと配布先で全文探索が既定に戻る**。移し漏れが無いことを検証で数える。

### 分割後の `AGENTS.md`

```markdown
## エージェント共通ルール

@./.claude/rules/agent-common.md

## プロジェクト概要

<!-- TODO: このリポジトリが何を実装するかを書く -->

## 開発・実行

<!-- TODO: ビルド・テスト・実行の方法を書く -->
```

- 受け入れ条件9は「共通ルールのimport＋プロジェクト概要」だが、現行の `## 開発・実行` 節も
  配布先所有のプレースホルダなので**残す**（受け入れ条件が禁じているのは「共通ルールが
  `AGENTS.md` に居座ること」であって、配布先所有の節を減らすことではない）。
- **`@` import の解決が未確認**（前提5）なので、`.claude/rules/` へ置くだけで読み込まれること
  （前提4）と**二重の担保**にする。片方が効かなくても共通ルールは読まれる。

### `seed` の雛形（対の計画が置く空ファイルの中身をここで埋める）

配布先へ配るのは `.claude/skills/apply-mr-workflow-to-project/templates/AGENTS.md` である。
**本家の `AGENTS.md` をそのまま配らない**：本家の `## プロジェクト概要` には
「このリポジトリは、issue駆動MRワークフロー機構……のテンプレートです」という**本家固有の本文が
3行ある**ため、そのまま配ると**どの配布先も本家を名乗った状態から始まる**（調査6）。

- 雛形の中身は、上の「分割後の `AGENTS.md`」から**プロジェクト概要の3行を落とし、TODOコメント
  だけにしたもの**。
- **雛形と本家で二重管理になるのは1節目（共通ルールのimport）だけ**である。import の書き方が
  変わったときに片方だけ直す事故を防ぐため、**両者の1節目が一致することをテストで表明する**
  （テスト本体は対の計画の `test_install_to_project.sh` へ足す。ここではその要求を出すに留める）。

## 作業2: `CLAUDE.md` / `GEMINI.md` のポインタ化（前提3のセット変更）

現状は末尾が**空の見出し**で終わっている。これは「ここへ書いてください」という誘いであり、
`core`（常に上書き）のまま残すと、配布先が素直に書いた内容が再適用で消える。

```markdown
<!-- 置き換え前（CLAUDE.md の末尾） -->
## Claude Code固有ルール

<!-- 置き換え後 -->
## Claude Code固有ルール

プロジェクト固有のルールは `.claude/rules/<名前>.md` へ置く（`.claude/rules/*.md` は
セッション開始時に自動で読み込まれる）。**このファイルは配布元が所有し、再適用で上書きされる**
ため、ここへ書き足さないこと。
```

- `GEMINI.md` の `## geminiCLI固有ルール` にも同じ趣旨の文を置く（参照先は同じ `.claude/rules/`）。
- 配布先が足した `.claude/rules/<新規>.md` は**manifestに載らないのでインストーラが触らない**
  （層分けの `path` に一致しないため）。この性質を文中で1文触れておく（読み手が
  「本当に消えないのか」を確かめられるように）。

## 作業3: `apply-mr-workflow-to-project/SKILL.md` の全面改訂

現行は `assets/` 前提・`.bak` を人間とAIで手マージする前提で書かれており、新方式と食い違う。

| 現行の節 | 改訂 |
|---|---|
| 概要 | 層分けとmanifestを持つ配布であることを最初に書く |
| Step 1（インストーラの実行） | オプションを `--force` / **`--allow-dirty`** / **`--dry-run`** の3つに更新 |
| Step 2（整合性確認） | `.claude/.asset-manifest.json` の確認を足す。`.gitignore` の説明を実際に配る行へ直す（現行は `/usage-state/` `/session-logs/` という**実在しないディレクトリ**を挙げている） |
| Step 3（動作検証） | `setup-gemini-links.sh` が走ったこと（リンクか実体コピーか）の確認を足す |
| 「適用される主要なAI資産」 | 層ごとの表へ組み替える（`core` は上書きされる／`seed` は最初の1回だけ／`merge` は追記・キー単位／`local` は触らない） |
| 「既存プロジェクトへの再適用とマージ相談フロー」 | **`core` の警告と `.bak`／`seed` は触らない／`--dry-run` で事前に差分を見る**という新しい流れへ書き直す |
| Goプロジェクト自動検知 | **現状の記述を維持する**（本issueの範囲外。層分けとは独立して動く） |

- **配布先が書き足す場所の案内を新設する**（`.claude/rules/<新規>.md` ／ `AGENTS.md` の
  プロジェクト概要 ／ `REVIEW-POINTS.local.md` の3つ）。これが無いと、`core` 化した
  `CLAUDE.md` へ書き足そうとする人が出る。

## 作業4: `DEVELOPERS.md` の書き換え（受け入れ条件10の後半）

「カスタムスキルの開発とパッケージング」節（41〜73行目）が `.skill` ビルド前提。

- 削除するもの: `sync-assets.sh` の実行（55行目）、`package_skill.cjs` によるビルド（58行目）、
  `mkdir -p build && mv …`（61行目）、`gemini skills install`（70行目）。
- 置き換え後の手順は「**本家をcloneし、配布先を指定して `install-to-project.sh` を実行する**」の
  1ステップになる。`.skill` の持ち運びが不要になった理由（配布物の実体が本家のワークツリーそのもの
  になり、manifestが版を記録するため）を1段落で添える。
- 節タイトルも「パッケージング」ではなくなるので改める（例:「他リポジトリへの配布」）。

## 作業5: `build/` の存廃を決める（調査7の宿題）

`build/` は `.skill` のビルド成果物の置き場としてのみ存在しており、ビルド工程が無くなる。
**決めずに放置すると、次の作業者には「漏れ」と区別できない。**

- **提案は「削除」**（`.gitignore` の `/build/`、`index.md` 45行目、
  `.claude/rules/directory-structure.md` 45行目のツリーから落とす）。将来別のビルドが要るなら、
  そのとき必要な形で作り直せばよく、**存在しない工程の記述がセッションごとに読み込まれる
  ルールファイルに残り続ける**ほうが害が大きい。
- ただし `.gitignore` の `/build/` 行は**対の計画が触る同じファイル**なので、実際の削除は
  対の計画の項目10とまとめて行う（同じファイルへ2つの計画から別々に手を入れない）。
- `commit` スキルの除外リストにある `build/` は**そのまま残す**（あちらは汎用の副産物リストで、
  このリポジトリに `build/` があるかどうかとは無関係）。

## 作業6: `REVIEW-POINTS.local.md` に伴うルールの更新

対の計画がスクリプトを直す一方、**ルール側の記述も直さないと運用が食い違う**。

| ファイル | 変更 |
|---|---|
| `.claude/rules/markdown-frontmatter.md`「typeの値」表 | `review-points` の対象を `**/REVIEW-POINTS.md` → `**/REVIEW-POINTS.md`・`**/REVIEW-POINTS.local.md` |
| `.claude/rules/docs-workflow.md` | 「flow-id 5-4で削除しない」の記述へ `.local` を加える |
| `.claude/rules/directory-structure.md` | 同上（`REVIEW-POINTS.md` の配置を説明している箇所） |

- `.claude/docs/spec/adversarial-review.md` は**spec なのでフェーズ4**で扱う（上記スコープ外）。

## 作業7: `ai-asset:` prefix の運用規約

`commit` スキルの prefix 表には既に `ai-asset`（AIアセットの変更）がある。**足りないのは
「どこまでが AIアセットか」の線引き**で、これが無いと `.claude/scripts/` の変更が `feat` と
`ai-asset` のどちらにもなりうる。

- `.claude/skills/commit/SKILL.md` の prefix 表の `ai-asset` 行へ、判断基準を1文添える。
  **`.claude/rules/` `.claude/skills/` `.claude/agents/` `AGENTS.md` `CLAUDE.md` `GEMINI.md`**
  （＝AIが読むもの）が対象で、**`.claude/scripts/` は対象外**（単体テストを持つ実装コードとして
  `feat`/`fix`/`refactor` を使う）。この線引きは
  `.claude/skills/issue-mr-flow/SKILL.md` の `【AIアセット作成】` の定義と同じにする
  （2箇所で違う線を引かない）。

## 触ってはいけない箇所（調査7。**この計画の作業中は近づかない**）

`.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は…changelogを対象に
含めない」に該当する。

| ファイル | 箇所 |
|---|---|
| `.claude/docs/ddr/i0033-01` `i0033-02` `i0033-03` `i0063-01` | 本文中の `sync-assets.sh` への言及（**DDR本文は変更しない**） |
| `.claude/docs/spec/issue-mr-workflow.md` 2304行目 | issue #63 のchangelogエントリ内 |
| `.claude/docs/spec/distribution-assets.md` 120行目 | `## 影響範囲 / ### issue #33（初版）` の中 |

- **`.claude/docs/spec/distribution-assets.md` は同じファイルに「直す行」と「触ってはいけない行」が
  混在する。** `sed` の一括置換をこのファイルへかけない（直す作業自体はフェーズ4）。
- `.claude/rules/directory-structure.md` 110行目の `assets/` は**スキルのバンドルリソース一般**の
  話で、`sync-assets.sh` の `assets/` とは無関係。**対象外**（消さない）。

## 検証（この計画の完了判定に実際に流すコマンド）

```bash
# 1. 9項目がすべて agent-common.md へ移り、AGENTS.md 側に残っていないこと
awk '/^## ルール/{f=1;next} /^## /{f=0} f && /^- /{c++} END{print c+0}' .claude/rules/agent-common.md
awk '/^## ルール/{f=1;next} /^## /{f=0} f && /^- /{c++} END{print c+0}' AGENTS.md

# 2. 落としやすい項目9（doc-search）が切り出し先にあること
grep -c 'doc-search' .claude/rules/agent-common.md

# 3. AGENTS.md が3節だけになっていること（共通ルール／プロジェクト概要／開発・実行）
grep -n '^## ' AGENTS.md

# 4. 雛形と本家の1節目（共通ルールのimport）が一致すること
diff <(sed -n '/^## エージェント共通ルール/,/^## プロジェクト概要/p' AGENTS.md) \
     <(sed -n '/^## エージェント共通ルール/,/^## プロジェクト概要/p' \
         .claude/skills/apply-mr-workflow-to-project/templates/AGENTS.md) \
  && echo '1節目が一致'

# 5. 雛形に本家固有の本文が残っていないこと
grep -c 'issue駆動MRワークフロー機構' \
  .claude/skills/apply-mr-workflow-to-project/templates/AGENTS.md

# 6. CLAUDE.md / GEMINI.md の見出しが空で終わっていないこと
tail -5 CLAUDE.md; tail -5 GEMINI.md

# 7. .skill 手順への参照が残っていないこと（DDR本文・changelogを除く）
grep -rn -e 'package_skill' -e 'gemini skills install' -e 'sync-assets' \
  --include='*.md' . | grep -v '/.claude/docs/ddr/' | grep -v '/plans/' \
  | grep -v '/reports/' | grep -v '/worklog/'

# 8. 触ってはいけない箇所が変わっていないこと（削除行が0であること）
git diff <ブランチ分岐点のSHA> -- .claude/docs/ddr/ | grep -c '^-[^-]' || echo 'DDRの削除行0'
```

- **検証1で AGENTS.md 側が `0` になること**が受け入れ条件9の直接の確認である。
- **`@` import が `.claude/rules/agent-common.md` へ解決するか**は、**切り出した直後の
  次のセッション開始時**にしか確認できない（前提5）。この計画の完了判定には含めず、
  確認できた／できなかったという事実を `reports/…md` と、フェーズ4のspecの
  「未決定事項・懸念点」へ残す。

## この計画の中で互いの前提を崩していないか（自己点検）

- **作業2（`CLAUDE.md` のポインタ化）は、作業1（`.claude/rules/` へ切り出す）が前提**である。
  「プロジェクト固有のルールは `.claude/rules/` へ」と案内する以上、そこが自動で読み込まれる
  ことを本家自身が示していなければならない。順序は 作業1 → 作業2。
- **作業3（SKILL.md）と対の計画の項目5（インストーラ）は、オプション名で結合する。**
  `--allow-dirty` / `--dry-run` の名前を対の計画側で変えるなら、SKILL.md も同時に直す。
- **作業5（`build/` 削除）は `.gitignore` を触るが、そのファイルは対の計画の項目10も触る。**
  実際の編集は対の計画側へ寄せ、こちらは判断の記録と `index.md` /
  `.claude/rules/directory-structure.md` の記述だけを担当する。
