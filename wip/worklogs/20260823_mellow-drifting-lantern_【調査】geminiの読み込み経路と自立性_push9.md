---
title: 20260823 mellow-drifting-lantern 【調査】geminiの読み込み経路と自立性 push9
type: log
description: issue #172 のスコープ拡大（3ディレクトリの採否 → .gemini/ に何を置くべきか）の経緯と、2回目の調査計画を立てるまでの記録
tags: [worklog, gemini, scope-change, phase2]
keywords: [スコープ拡大, 自立性, 非対称, 公式ドキュメント, skills, agents, 結論5-2, 訂正, 374件]
---

# push9: スコープ拡大と2回目の調査計画

## 何が起きたか

フェーズ3を完了（flow-id 3-10）した直後、ユーザーから次の問いが来た。

> 配布先でclaude codeしか使わなかったら.claudeのみを残す、geminiCLIしか使わなかったら
> .geminiのみを残すような対応をしたとしてもそれぞれ独立で動くような設計と現在のAIアセットの
> 記載になっているのであれば良いがどうなっている？

**この問いで、issue #172 の切り方が合っていないことが分かった。**

## 学び1: 「読まれるか」を測っていたのに、「読まれる側が何を指すか」を測っていなかった

フェーズ2の軸1は「そのパスを実行時に読む経路があるか」を3ディレクトリについて測り、
0件という正しい答えを出していた。**しかし逆向き——Gemini CLI が読むもの（`settings.json`
`skills/` `agents/`）が何を指しているか——は一度も測っていなかった。**

測ってみると 374件（skills 366・agents 8）が `.claude/…` を指していた。

```
Gemini CLI ──読む──> .gemini/settings.json ──指す────> .claude/hooks/*.sh
           ──読む──> .gemini/skills/   ──指す(366件)──> .claude/scripts/, .claude/docs/
           ──読む──> .gemini/agents/   ──指す(8件)────> .claude/scripts/vcs/Provider.sh
```

**教訓: 「Xは使われているか」を調べたら、「Xを使う側は何を使っているか」も対で調べる。**
片方向だけだと、今回のように「複製をやめるか」という小さい問いに閉じてしまう。

## 学び2: 「未観測だから推論で行く」の前に、公式ドキュメントを探す手が残っていた

フェーズ2・3を通して、私は軸1を「Gemini CLI 実機が無いので未観測の推論」として扱い、
それを結論9として明記していた。**実機が無いことは正しかったが、公式ドキュメントを読む手を
一度も試していなかった。** ユーザーの問いをきっかけに調べたところ、
`google-gemini/gemini-cli` の `docs/` に読み込み経路が明記されていた。

- `docs/cli/skills.md` — workspace skills は `.gemini/skills/` または `.agents/skills/`
- `docs/reference/commands.md` — `/agents reload` が `~/.gemini/agents` と `.gemini/agents` を再スキャン
- `docs/cli/gemini-md.md` — `GEMINI.md` の探索と `@./` import
- `docs/reference/configuration.md` — `settings.json` のトップレベルキー

取得は `curl -sfL https://raw.githubusercontent.com/...` で行った（`google-gemini.github.io` は
egress proxy にブロックされた）。**`WebFetch` が1経路で失敗しても、別経路を試す。**

**教訓: 「実機が無い」は「観測できない」と同義ではない。** 一次情報の候補を、実機・公式
ドキュメント・ソースコードの3つで数え上げてから「未観測」と書く。

## 学び3: 自分の結論の誤りが、この調べ方で初めて見つかった

フェーズ3レポートの**結論5-2は誤りだった**。

> 軸1の0件根拠は `.gemini/rules/` `.gemini/skills/` にも同じ強さで当たる

**`.gemini/skills/` は読まれる。** これは案2（hooks/ scripts/ だけ外す）の却下理由の片方
だったので、根拠が1つ崩れた（もう片方——残る `.gemini/docs/` から2件切れる——は生きている）。

敵対的レビューは2回（フェーズ3だけで）走らせ、計23件の指摘を反映していたが、
**この誤りは1度も指摘されなかった**。レビューには diff と REVIEW-POINTS しか渡していないため、
「Gemini CLI の公式ドキュメントを見に行く」という手はレビュー側にも無かった。

**教訓: 敵対的レビューは「書かれたものの内部矛盾」には強いが、「外部の一次情報と突き合わせる」
ことはしない。** 外部仕様に依存する結論は、レビュー回数を増やしても検証されない。

## やったこと

1. `.claude/` 単体・`.gemini/` 単体の可否を実測（非対称であることを確認）
2. 公式ドキュメントで読み込み経路を裏取り
3. issue #172 のタイトル・本文・受け入れ条件を更新（スコープ拡大）＋経緯をコメント
4. 全体作業計画（md・html）へ「スコープ拡大」節を追加、方針・フェーズ2・スコープ外・検証・
   受け入れ条件対応を更新
5. 2回目の調査計画 `wip/plans/【調査】geminiの読み込み経路と自立性.md`（＋html）を作成（Q7〜Q11）

## 次にやること

- この計画への敵対的レビュー（ユーザーの常設指示）
- Q7〜Q11 の実施。**Q7 を最初に**（以降の前提になる）
