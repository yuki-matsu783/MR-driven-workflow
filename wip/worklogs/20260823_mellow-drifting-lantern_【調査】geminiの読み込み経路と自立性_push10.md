---
title: 20260823 mellow-drifting-lantern 【調査】geminiの読み込み経路と自立性 push10
type: log
description: Q7・Q8・Q10・Q11 の実施記録。公式ドキュメントの取得手順と、4ディレクトリ除去時のリンク切れ再測定で得た結果
tags: [worklog, gemini, phase2, 調査]
keywords: [Q7, Q8, Q10, Q11, agents-skills, 壊れたリンク, 18件, 1件, GEMINI.md, 実測]
---

# push10: 2回目の調査（Q7・Q8・Q10・Q11）の実施

## うまくいったこと

### 公式ドキュメントの取得は raw.githubusercontent.com 経由で通った

`google-gemini.github.io` は egress proxy にブロックされた（`EGRESS_BLOCKED`）。
`raw.githubusercontent.com` は `curl -sfL` で通る。ファイル名は総当たりで探した。

```bash
for f in docs/cli/skills.md docs/reference/commands.md ...; do
  curl -sfL "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/$f" -o "$(echo $f|tr / _)"
done
```

- `api.github.com` の tree API は認証なしでは通らなかった（exit 22）ので、
  ファイル一覧を取ってから絞る、はできなかった。
- Claude Code 側は `WebFetch https://code.claude.com/docs/en/skills` が通った（93KBで
  ツール結果がファイルへ退避されたので、`grep` で当たった）。

### 4ディレクトリ除去時のリンク切れを、1回目と同じ尺度で測れた

**測り方の妥当性は「1回目の18件を再現できるか」で確かめた。** 3ディレクトリ版を同じ
スクリプトで測って `rules/`→`docs/` 17・`skills/`→`docs/` 1 の内訳まで一致したので、
4ディレクトリ版の1件も同じ尺度の値だと言える。

```python
# 「壊れたリンク」= 解決先が除去対象 かつ リンク元が生き残る
broken = [l for l in links if l.target_top in removed and l.source_top not in removed]
```

**リンク元が除去対象なら「壊れたリンク」ではない**（リンクごと消えるため）——この1行が
結果を 18 → 1 に変える。計画に書いた見立てはここで実証された。

## 分かったこと（意外だった点）

### 4つ外すほうが3つ外すより「軸2の被害が小さい」

直感に反する。除去範囲を広げたのに被害が減るのは、**17件のリンク元が `rules/` 自身**
だからである。フェーズ3が「docs/ を外すと18件切れる」を案3の却下理由の一部にしていたが、
**`rules/` を一緒に外せばその論拠は成り立たない**。

### 論点3は成立しなかった

`.agents/skills/` は Gemini CLI 側だけの機能で、**Claude Code の公式ドキュメントには
`.agents` の言及が0件**だった。共用パスとして使うと Claude Code からスキルが見えなくなる。

- **「0件」を根拠にするときの限界も書いた。** 記載が無い＝未対応とは論理的には言えない。
  ただし**未文書の挙動に依存する設計は採れない**、という形なら結論として使える。

### 依存を明示する先は実質1つしかない

候補を「配布されるか」「Gemini CLI が読むか」の2軸で並べたら、**両方を満たすのは
`GEMINI.md` だけ**だった。`README.md` は `layer: exclude` で**配布先に存在しない**——
ここに書く案は最初から成立しなかった。

**教訓: 「どこに書くか」は、書きやすさではなく到達経路で決める。** 2軸の表にするまで、
私は spec へ書けば足りると思っていた。

## やったこと

1. Q7: 公式ドキュメント6本を取得して読み込み経路を確定
2. Q8: SKILL.md 9件の frontmatter を実測（9/9 が要件充足）
3. Q10: `.gemini/` の全内訳を実測（`rules/` 8ファイル・トップレベル5ファイルは1回目に無かった）、
   3ディレクトリ版・4ディレクトリ版のリンク切れを再測定
4. Q11: `dist-layers.json` と `install-to-project.sh` を読み、配布の出し分けが無いことを確認
5. レポート md・html を作成し、計画の検証項目（Q節4・出典・実機の言及・判断混入）を全て実行
6. **判断混入の検査が空振りでないことを確認**（「案Aを採用する」を一時的に混ぜて検出を確認し、復旧）
