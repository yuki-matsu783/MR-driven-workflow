---
title: 【調査】.gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響
type: plan
description: .gemini/hooks/ scripts/ docs/ を生成対象から外すかを判断するための、参照件数・相対リンクの解決可否・除外時の影響を調べる個別調査計画
tags: [plan, gemini, sync-gemini-assets, 調査]
keywords: [参照件数, 相対リンク, 解決可否, COPY_EXCLUDED_PREFIXES, 除外, 配布, 単体テスト, 死蔵]
---

# 【調査】.gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響

## 前提（合意状況）

- 上位の計画: `wip/plans/mellow-drifting-lantern.md`（全体作業計画。flow-id 1-4 で作成）。
  **非対話セッションのため flow-id 1-5 の人間による合意は得ていない**（進捗記号は `[]` のまま）。
- issue #172 の本文が示す見立て（hooks/ scripts/ は使われない、docs/ は外すとリンクが切れうる）は
  **仮説として扱う**。この調査で件数付きに裏を取ってから採否を決める。

## この計画で何をするか

`.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` の3ディレクトリについて、
**「誰が・どのパスで参照しているか」を件数で確定させる**。判断そのもの（外す／残す）は
フェーズ3で行い、この調査ではその材料だけを揃える。

## 変更対象

調査のみのため、リポジトリのコード・設定は変更しない。生成される成果物は次の3つ。

| ファイル | 操作 | 何をするか |
|---|---|---|
| `wip/reports/20260823_mellow-drifting-lantern_gemini生成対象の参照実態.md` | 新規 | 調査結果の正文（Q1〜Q6の答え） |
| 同名の `.html` | 新規 | 上記の人間レビュー用ビュー |
| `wip/worklogs/20260823_mellow-drifting-lantern_【調査】gemini生成対象3ディレクトリの参照実態_push2.md` | 新規 | 試行錯誤の詳細ログ |

## 方針

**「参照が無い」を主張するには、探し方そのものを結果に書く。** grepのパターン・対象範囲・
除外条件を調査結果へ書き残し、読み手が同じコマンドで再現できるようにする。
0件という結果は、パターンが実データに当たっていないだけでも得られてしまうため
（`.claude/rules/shell-script-style.md`「異常が無ければ何も出ない検証」と同根）。

**そのため、各グレップは「当たることが分かっている対照」とセットで実行する。**
たとえば「`.gemini/scripts/` への参照が0件」を示すときは、同じパターンで
`.claude/scripts/` を検索して非0件が返ることを併記する。パターンが壊れていれば両方0件になる。

**参照の「経路」を3つに分けて数える。** 混ぜると、片方の経路だけで使われているものを
「使われていない」と誤判定する。

| 経路 | 何を見るか |
|---|---|
| 設定からの実行 | `.gemini/settings.json` の hook `command` が指すパス |
| ドキュメント間のリンク | `.gemini/` 配下の md から `../` 等で辿る相対リンクの解決先 |
| 資産からの呼び出し | `.gemini/rules/` `.gemini/skills/` `.gemini/agents/` の本文が指すスクリプトのパス |
| `.claude/` 側からの名指し | `.claude/` 配下のスクリプト・spec・テストが `.gemini/<サブディレクトリ>/` を文字列で指す箇所 |

## 調査項目

| # | 問い | 答えの形 |
|---|---|---|
| Q1 | `.gemini/hooks/` 配下を指す参照は何件か。変換後の `.gemini/settings.json` の hook `command` は何を指しているか | 件数＋実際のパス一覧 |
| Q2 | `.gemini/scripts/` 配下を指す参照は何件か。`.gemini/` 配下の資産からの呼び出しはどのパスを指しているか | 件数＋対照（`.claude/scripts/` の件数） |
| Q3 | `.gemini/docs/` を解決先とする相対リンクは `.gemini/` 配下に何件あるか。逆に `.gemini/docs/` 配下から `.gemini/` 内の他ファイルへ向かうリンクは何件か | 双方向の件数 |
| Q4 | 3ディレクトリを除外した場合、`.gemini/` 内で解決できなくなる相対リンクは何件になるか | ディレクトリごとの件数 |
| Q5 | 除外を実装する場合、`COPY_EXCLUDED_PREFIXES` の現在の意味論（完全一致）で足りるか。既存テストのどれが影響を受けるか | 要否＋影響テスト名 |
| Q6 | 除外は何をどれだけ減らすか（ファイル数・バイト数・`--check` の所要時間） | 実測値 |

## やらないこと（スコープ外）

- **判断そのもの（外す／残す）を出すこと。** この調査は材料を揃えるまでで、判断はフェーズ3。
- **Gemini CLI 実機でのロード確認。** 実行環境に Gemini CLI が無い（既知の未決定事項）。
- **`.claude/` 配下のドキュメントが `.claude/` 自身をどう参照しているかの棚卸し。**
  これは `.gemini/` の生成対象の判断に影響しない。
  **一方、`.claude/` 側から `.gemini/` のサブディレクトリを名指ししている記述は調査対象に含める**
  （「元である」ことと「`.gemini/` のパスを参照していない」ことは別である。実際に
  `check-doc-references.sh` の除外定義・同 spec の表・`test_search_frontmatter.sh` の
  アサーションが `.gemini/scripts/` `.gemini/docs/` を名指ししており、これらは
  「除外したときに何が壊れるか」に直接効く）。
- **変換規則（agents frontmatter・settings.json のキー対応）の点検。**

## 検証

**探索は md に限定せず、リポジトリ全体を対象にする**（`.sh`・`.json` にも参照がある）。
**件数は `.gemini/` を除いた「元」の側で数え、`.gemini/` 側は別カウントとして併記する**
（`.gemini/` は `.claude/` の逐語コピーなので、同時に探索すると同じ1つの参照が2件になる）。

```bash
# Q1/Q2: リポジトリ全体（.gemini/ を除く「元」の側）で数える
grep -rIn -e '\.gemini/scripts/' . \
  --exclude-dir=.git --exclude-dir=.gemini --exclude-dir=wip --exclude-dir=usage | wc -l
# 対照（同じ形で非0が返ること。0なら探し方が壊れている）
grep -rIn -e '\.claude/scripts/' . \
  --exclude-dir=.git --exclude-dir=.gemini --exclude-dir=wip --exclude-dir=usage | wc -l
# .gemini/ 側の複製は別カウントで併記する
grep -rIn -e '\.gemini/scripts/' .gemini | wc -l
```

**Q3/Q4 はリテラル文字列のgrepでは測れない。** `.gemini/` 配下のリンクは `.claude/` の逐語コピー
ゆえ `](../docs/spec/x.md)` の形で書かれ、文字列 `.gemini/docs/` としては現れない。リテラル一致で
数えると **0件と出たうえに、対照（`.claude/docs/`）は非0を返す**ため、上の合格条件を満たしたまま
「docs/ を外してもリンクは切れない」という誤った結論に到達できる。そこで**リンクを抽出して
解決先を正規化し、接頭辞で判定する**。

```bash
# 各 md のディレクトリを基準に相対リンクを解決し、解決先が .gemini/<対象>/ に入るものを数える
grep -rIno --include='*.md' -e '](\.\./[^)]*)' .gemini |
  while IFS= read -r hit; do
    src="${hit%%:*}"; rest="${hit#*:}"; link="${rest#*:}"; link="${link#](}"; link="${link%)}"
    printf '%s\t%s\n' "$src" "$(realpath -m --relative-to=. "$(dirname "$src")/${link%%#*}")"
  done | awk -F'\t' '{print $2}' | grep -c '^\.gemini/docs/'
# 対照: 解決した結果が非0になること（0なら抽出・正規化のどこかが壊れている）
```

**Q4 は「除外後も残るファイルから、除外されるファイルへ向かうリンク」だけを数える。**
除外対象の内部で完結するリンク（`.gemini/docs/` 内の docs→docs）は、リンク元ごと消えるため
切れリンクにならない。両者を混ぜると件数が一桁変わる。

```bash
# Q6 の実測
find .gemini/hooks .gemini/scripts .gemini/docs -type f | wc -l
for p in .gemini/hooks .gemini/scripts .gemini/docs .gemini; do du -sb "$p"; done   # 個別に測る
time bash .claude/scripts/src/sync-gemini-assets.sh --check
```

合格条件:

- Q1〜Q4 に**件数で**答えられている（「無い」ではなく「0件である」）。
- 0件と答えた問いには、**同じ探し方で非0件が返る対照**が併記されている。
  リテラル一致で測れない問い（Q3/Q4）では、対照も**解決後の件数**で取る。
- Q1/Q2 の件数が、`.gemini/` の複製を二重計上していない（「元」の側と `.gemini/` 側を分けている）。
- 3ディレクトリそれぞれについて「外す／残す」の判断材料（Gemini CLI が読むか・リンクが切れるか・
  除外時に何が壊れるか）が揃っている。

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172 / PR #193。
