# 【AIアセット反映】get_providerのホスト判定化

対象issue: [#45](https://github.com/yuki-matsu783/MR-driven-workflow/issues/45)
全体作業計画: `plans/mutable-beaming-leaf.md`
先行する反映計画: `plans/【設計反映】get_providerのホスト判定化.md`

作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `AGENTS.md` `CLAUDE.md`
へ反映する。**設計反映（spec/ddr）の実施・レビューが完了してから着手する**
（`.claude/skills/issue-mr-flow/SKILL.md`。flow-id 4-6〜4-9を2セット回す）。

全体作業計画では「反映なしで終える可能性がある」としていたが、実装中に**3件の候補**が出た。
うち1件は反映すべきと考えており、残り2件はレビューで採否を判断したい。

## 候補1: `set -e` 配下で終了コードを検査するテストの書き方（**反映を推奨**）

反映先: `.claude/rules/shell-script-style.md`「テスト」節

### 何があったか

`provider_from_remote_url` が「ホスト名が空なら終了コード1」を返すことのテストを、最初こう書いた。

```bash
assert_eq "..." "1" "$(provider_from_remote_url 'https://' 2>/dev/null; echo $?)"
```

実行すると `1` が返って**テストは通った**。しかしテストスクリプトも `Provider.sh` も
`set -euo pipefail` を宣言しており、コマンド置換のサブシェルは `-e` を引き継ぐ。関数が失敗した
時点でサブシェルが終了すれば `echo $?` に到達せず、空文字列が返って別の理由で落ちる書き方である。
**「たまたま通っている」状態を残すべきでない**と判断し、`if` の条件式（`-e` が一時停止される文脈）へ
寄せた。

```bash
if provider_from_remote_url 'https://' >/dev/null 2>&1; then
  empty_host_status=0
else
  empty_host_status=1
fi
assert_eq "..." "1" "$empty_host_status"
```

### なぜルール化する価値があるか

既存の「エラー方針」節は「失敗しても処理を継続したい箇所」の書き方（関数をコマンド置換・
明示サブシェルで呼ぶ）を扱っているが、**テストで終了コードそのものを assert したい**という用途は
扱っていない。しかもこの誤りは**テストが通ってしまうため気づけない**種類のものである。
「テスト」節に3〜5行で足す。

### 書く内容（案）

- `"$(func; echo $?)"` の形で終了コードを取らない（`set -e` 配下ではサブシェルが `echo` に
  到達しない可能性がある）。
- `if func; then status=0; else status=1; fi` の形にする。`if` の条件式では `-e` が一時停止される
  （同ファイル「エラー方針」節を参照）。
- 悪い例／良い例のコードブロックを添える（同節の既存の書き方に合わせる）。

## 候補2: 仕様書の記述と実装の食い違い（**レビューで採否を判断したい**）

反映先候補: `.claude/rules/docs-workflow.md`

### 何があったか

`.claude/docs/spec/issue-mr-workflow.md` は `Provider.sh` を
「`git remote get-url origin` の**ホスト名**（`github.com` / `gitlab.*`）でプロバイダを判定し」と
説明していたが、実装は**URL文字列全体への部分一致**だった。この食い違いがissue #45のバグそのもので
あり、specだけを読んでいる限り「ホスト名で判定しているのに、なぜself-hostedを弾くのか」は
分からない状態だった。

### 反映するとしたら

「specの『現在の状態を説明する節』を更新・参照する際は、記述が実装と一致しているかを実コードで
確認する」といった趣旨を docs-workflow.md へ足す。

### 判断が要る理由

**一般論として正しいが、当たり前すぎて実効性が薄い可能性がある。** 既存ルールは
「issue #24でこう壊した」のように具体的な事故と対処がセットになっているものが多く、本件は
「気をつける」以上の具体的な手順に落ちにくい。**入れないという判断も妥当**だと考えている。
入れる場合は、issue #45の実例（specは「ホスト名で判定」、実装は全体一致）を必ず添えて、
抽象的な訓示にしない。

## 候補3: 実機検証スクリプトのNGは、まず呼び出し側を疑う（**反映不要と考える**）

実機検証で3件NGが出たが、いずれも `Provider.sh` の欠陥ではなく検証スクリプト側の誤りだった
（MR番号の取り違え／存在しない関数名 `get_compare_url` の呼び出し／引数の数の誤り）。

ただしこれは**worklogに残せば十分な粒度**で、恒久ルールにするほどの一般性は無いと考える。
`get_compare_url` が公開ディスパッチャではない件は、**AIアセットではなくspec側**（設計反映の
候補2）で「表に載る公開インターフェースと内部ヘルパーの区別」として扱うのが適切。

## 反映しないもの

- `.claude/skills/issue-mr-flow/SKILL.md`: 本issueでフロー自体の不備は見つかっていない。
  なお「チャットで受けたレビュー判断をMRコメントに残す」（issue #50）・「worklog削除タイミングの
  記述矛盾」（issue #51）は起票済みの別issueであり、本issueでは扱わない。
- `.claude/rules/powershell-encoding.md`: 本issueに `.ps1` は無い。
- `.claude/rules/git-workflow.md`: hookの誤検知等、新しい知見は無かった。

## worklog

flow-id 4-6（AIアセット反映の実施）の開始時に
`worklog/20260819_mutable-beaming-leaf_【AIアセット反映】get_providerのホスト判定化_push<N>.md` を作成する。
