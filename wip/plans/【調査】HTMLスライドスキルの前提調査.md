---
title: 【調査】HTMLスライドスキルの前提調査
type: plan
description: issue #168 のスキル・テンプレート・サブエージェント2本を設計するために必要な既存規約・置き場所・命名の調査計画
tags: [plan, research, slides]
keywords: [調査計画, テンプレート規約, サブエージェント規約, スキル名, 出力先, JSONスキーマ, dist-layers, sync-gemini-assets]
---

# 【調査】HTMLスライドスキルの前提調査

- issue: #168 / PR: #194
- フェーズ: 2〈調査〉 flow-id 2-1

## 前提（合意状況）

- 上位計画: `wip/plans/html-slides-skill-plan.md`（flow-id 1-4 で作成。**flow-id 1-5 の人間合意は
  非対話セッションのため未取得**であり、ユーザーの当初指示を包括的な承認として進めている。
  上位計画に人間から異議が出た場合、本計画のQ1〜Q8とその結論も見直しの対象になる）。
- したがって Q3（スキル名）・Q4（出力先）・Q5（スキーマの置き場所）の採用案は、フェーズ3の
  前提になるが**人間の再確認対象**である（PRレビューで異議があれば差し戻す）。

## この計画で何をするか

フェーズ3で作る4点（スライドテンプレート・SKILL.md・サブエージェント2本・構成案JSONスキーマ）の
設計を確定するために、既存の規約・実例・影響範囲を調べ、個別作業計画（flow-id 3-1）が
書ける状態にする。

## 変更対象

本計画はリポジトリのファイルを変更しない（調査のみ）。成果物は調査レポート
`wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md`（+同名.html）の新規作成のみ。

## 調査項目（問いの形）

| # | 問い | 調べ方 | 何が分かれば次へ進めるか |
|---|---|---|---|
| Q1 | 既存テンプレート3本（`plans.template.html` / `reports.template.html` / `canvas-report.html`）の冒頭コメント・スタイル変数・ダークモード対応・プレースホルダ検査はどう作られているか | 3本を読み、共通する構成要素を表にする | `slides.template.html` が踏襲すべき要素の一覧（冒頭コメントの構成・`--bg` 等のCSS変数・`prefers-color-scheme`・`grep -c` 検査） |
| Q2 | サブエージェント定義（`.claude/agents/` 既存2本）のfrontmatter・本文構成・ツール制限はどう書かれているか | `adversarial-reviewer.md` / `issue-mr-resume.md` を読む | 新規エージェント2本のfrontmatterキー（`name`/`description`/`tools`/`model`等）と本文の見出し構成の型 |
| Q3 | スキル名は何にするか | 既存スキル名（`canvas-report` 等）の命名傾向を確認し、候補を比較する | ディレクトリ名（`.claude/skills/<スキル名>/`）の確定 |
| Q4 | スライドHTMLの出力先ディレクトリの既定はどこにするか | `wip/reports/` の寿命（flow-id 5-5で削除）・`.gitignore`・`directory-structure.md` に加え、**新規出力先を選んだ場合の影響先**として `dist-layers.json`（層分け・`local` エントリ）・`check-dist-coverage.sh` の検査2（`.gitignore` 全行の被覆）・`cleanup-task.sh` の削除対象（`.mrworkflow.json` の `plansDir`/`worklogDir`/`reportsDir`）を確認し、選択肢（`wip/reports/`／恒久ディレクトリ新設／その他）を比較する | 既定の出力先と、その寿命・`.gitignore`・配布層・片付け対象の扱いの確定（issue #168「期待する動作 4.」） |
| Q5 | 構成案JSONスキーマはどこに・どの形式で置き、**最低限何を保持すべきか** | 置き場所は `directory-structure.md` の `assets/`・`references/`・`scripts/` の語彙定義から選ぶ（上位計画は `assets/`/`references/` の2択で書いたが、語彙は3つあるため `scripts/` も比較対象へ加える。差分の理由はこの1行が正）。**内容は「.pptx 書き出しがそのまま入力にできる」（受け入れ条件6）を満たすために、スライド型8種ごとの構造・話者ノート・必須／任意フィールドの区別など、スキーマが最低限保持すべき情報を洗い出す**。検証手段（jq）も確認する | スキーマファイルの置き場所・形式（JSON Schema）・保持すべき情報の一覧・SKILL.md/エージェント定義からの参照方法 |
| Q6 | 新規ファイルは配布・同期・インデックスの仕組みにどう影響するか | `dist-layers.json` の層分け定義・`check-dist-coverage.sh` の検査対象・`sync-gemini-assets.sh` の変換対象・`extract-frontmatter.sh` の走査対象を確認する | 追加が必要な設定変更の一覧（無ければ「変更不要」の根拠） |
| Q7 | ドキュメントへの追記はどこに必要か | `directory-structure.md` のツリー・`markdown-frontmatter.md` の type 表に加え、**同ファイルの「対象外・特殊対応ファイル」表**（`.claude/agents/*.md`・`.claude/skills/*/SKILL.md` は `description` を重複追加せず既存キーを流用する規定）を確認する | フェーズ4で追記すべき箇所の一覧（`type: skill` / `type: agent` は既存値で足りるか、`description` の扱いを含む） |
| Q8 | ページ送り・進行表示・印刷レイアウトはどう実装し、どう検証するか | 既存3本に前例が無い（script・`@media print` とも0件〜canvas4件のみ）ため、`file://` で開くだけで動くキーボード/クリックハンドラの実装方式・`@media print` での1スライド1ページの割り付け方式を整理し、**ブラウザの無い実行環境（Claude Code on the web）で確認できる範囲／できない範囲を切り分ける**（できない範囲は誰がいつ実機確認するかを決める）。受け入れ条件4（SKILL.mdの手順どおりで1本完成する）の確認方法も同じ枠で決める | フェーズ3の実装方式と検証計画（機械検証の項目一覧と、人間の実機確認に残る項目一覧） |

## 方針

- **一次情報はリポジトリ内のファイルとissue本文に限る**（外部Webは参照しない。調べ方の列に
  挙げたファイルを読む）。
- **打ち切り基準**: 各問いは「何が分かれば次へ進めるか」列の状態に達したら打ち切る。
  それ以上の深掘り（実装の細部）はフェーズ3の個別作業計画側で行う。
- **答えが割れた場合（複数案が拮抗する場合）**: 比較表（利点・欠点・採否と理由）を調査レポートへ
  残して1案を推す。最終確定はフェーズ3の計画レビュー（PR上）に委ねる。
- 調査結果は計画ファイルへ書かず、`wip/reports/` のレポートへ書く（issue #87 の分離）。

## やらないこと（スコープ外）

- テンプレート・スキル・エージェントの実装（フェーズ3へ送る。flow-id 3-1 の個別作業計画で確定）
- **リポジトリ直下への新規ディレクトリ追加の提案**（Q4の出力先の選択肢として比較はするが、
  採用判断とDDR記録はフェーズ3の計画レビューとフェーズ4へ送る。なお、スキル配下のサブディレクトリ
  （`assets/` `references/` `scripts/`）は Q5 の対象に**含む**）
- 既存テンプレート3本の変更

## 検証

調査レポート（md+html）の完成を、次の実行可能なコマンドで機械的に検査する。

```bash
# (1) Q1〜Q8の未回答が0件であること（レポートの見出しにQ1〜Q8が全て存在する）
for q in Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8; do
  grep -c "## ${q}" "wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md"
done   # 合格: 8行すべて 1 以上

# (2) HTMLビューにプレースホルダが残っていないこと
grep -c '<!-- ここに書く' "wip/reports/2026-08-23_html-slides-skill-plan_前提調査.html"   # 合格: 0

# (3) HTMLビューが外部を読みに行かないこと（2種とも0件）
grep -nE "(src|href)=['\"]?(https?:)?//" "wip/reports/2026-08-23_html-slides-skill-plan_前提調査.html"
grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "wip/reports/2026-08-23_html-slides-skill-plan_前提調査.html"

# (4) レポートmdのfrontmatterが index.jsonl に載ること
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null 2>&1
grep -c '前提調査' wip/reports/index.jsonl   # 合格: 1 以上
```

合格条件: (1) 8問すべて1以上、(2) 0、(3) 出力なし、(4) 1以上。
加えて Q3・Q4・Q5 の答えに選択肢の比較（利点・欠点・採否）が含まれることをレビューで確認する
（比較の有無は機械判定できないため、この1点のみ目視）。
