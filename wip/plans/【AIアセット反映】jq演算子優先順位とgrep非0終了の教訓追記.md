---
title: 【AIアセット反映】jq演算子優先順位とgrep非0終了の教訓追記
type: plan
description: issue #151 のフェーズ4〈反映〉。実装作業の副産物として踏んだ2件の罠（jqの|の優先順位、grep -oのパイプ中間位置でのpipefail依存中断）をshell-script-style.mdへ追記する個別反映計画
tags: [issue-mr-flow, ai-asset, shell-script-style, jq, grep]
keywords: [演算子優先順位, パイプ, pipefail, grep -o, 非0終了, set -e, 敵対的レビュー, 作り込み, 再現性]
---

# 【AIアセット反映】jq演算子優先順位とgrep非0終了の教訓追記

issue #151（PR #197）フェーズ4〈反映〉flow-id 4-1。

## 前提（合意状況）

- 依拠する作業結果: `wip/reports/20260830_session-start-user-utterance-reinject_作業結果.md`
  「想定と異なった点」節（flow-id 3-8〜3-9で人間レビュー承認済み）
- 敵対的レビュー（フェーズ4計画段階・1回目）で、以下の指摘を受けて全面的に書き直した:
  - jq優先順位の説明が事実と逆だった（実測で訂正）
  - 手順1の起点列挙がworklogを走査しておらず、同種の罠の再発（push7）を見落としていた
  - grep -oの罠が「-o固有」「末尾にあるとき危険」という誤った条件で書かれていた
  - 手順4（反映先の形態の2軸選定・削除/統合の検討）が抜けていた
  - 検証が追記前から通ってしまう空振りだった

## この計画で何をするか

フェーズ3の実装作業中、敵対的レビュー指摘の修正作業そのものが新しい欠陥2件を作り込み、単体
テストで即座に検出・再修正した。この2件はいずれも既存アセットに記述の無い罠と判定できたため、
`.claude/rules/shell-script-style.md` へ追記する。

## 反映対象の洗い出し（AIアセット）

### 手順1: 起点の列挙

`references/planning.md`が定める3つの入力（`worklog/` / `reports/` / MRのレビューコメント）を
すべて走査した。

| 入力 | 走査した範囲 | 結果 |
|---|---|---|
| `wip/worklogs/` 全6本 | 「ダメだったこと」「試したこと」節 | push7に1件ヒット（下記） |
| `wip/reports/20260830_..._作業結果.md` | 「想定と異なった点」節 | 2件ヒット（下記） |
| MRのレビューコメント | 作業結果レポートに転記済みの敵対的レビュー指摘（フェーズ3・2回目）を参照 | 上記2件と同一（レビュー指摘の修正作業中に発生したもの） |

列挙した項目（3件、うち2件は同一の罠のため統合）:

1. **push7**（フェーズ2・調査段）: 集計jqが `map([.[0].message.content|type, length])` と書いた
   ところ、`[.[0].message.content | (type, length)]` と解釈された（`,` が `|` より強く結合する）。
2. **flow-id 3-6後の敵対的レビュー2回目**（フェーズ3・作業実施段）: `... or has("counts") | not`
   を「`A or (B|not)`」の意図で書いたところ、`(A or has("counts")) | not` と解釈された
   （`or` が `|` より強く結合する）。
3. 同じ修正作業中: `grep -o` を切り出した関数内でパイプの途中に置いたところ、`set -eo pipefail`
   配下でのみマッチ0件が呼び出し元を中断させた。

1と2は**同じ一般則（jqの`|`は他のほぼ全ての演算子より優先順位が低い）の異なる現れ**であり、
反映は1本の項目へ統合する。3は別の罠として扱う。

### 手順2: 4類型への分類

| # | 内容 | 分類 | 根拠 |
|---|---|---|---|
| 1・2 | jqの`\|`の優先順位（`or`/`,`いずれとの組み合わせも含む） | **(a) 該当するアセットが無かった** | `.claude/rules/shell-script-style.md`全体に「優先順位」の語を含む記述が無い（`grep -n '優先順位' .claude/rules/shell-script-style.md` が0件） |
| 3 | `grep -o`のパイプ中間位置でのpipefail依存中断 | **(a) 該当するアセットが無かった** | 「エラー方針」節はpipefail自体は扱うが、`grep`の終了コードとの組み合わせを扱った記述が無い（下記「痕跡の確認」で本文grep済み） |

### 手順3: 痕跡の確認と打ち切り

**段階1（同一MR内の再現性）**:

- jq優先順位（項目1・2）: **本MR内で2回発生**（push7＝フェーズ2、flow-id 3-6後＝フェーズ3）。
  **再現性ありと確定**。段階2（痕跡の確認）へ進む。
- `grep -o`（項目3）: 本MR内で1回のみ。再現性なし。(a)はこの時点では確定しないが、痕跡確認
  （段階2）で痕跡なしを確認できれば(a)のまま反映してよい（planning.md「再現性が確かめられても
  (a)は確定しない」の逆＝再現性が無くても痕跡が無ければ反映できる、という非対称ではなく、
  「再現性なし→反映しない」の対象は段階1のみでの打ち切り判断であり、段階2へ進んで痕跡なしを
  確認した場合はそのまま反映してよい、という運用に沿う）。

**段階2（doc-search + grep。単語で検索する）**:

```
$ bash .claude/scripts/src/search-frontmatter.sh --text '優先順位' --type ddr --format count
matched=3

$ bash .claude/scripts/src/search-frontmatter.sh --text 'grep' --format count
matched=14
```

`doc-search`はfrontmatterのキーワードにヒットするだけで、本文の記述の有無は示さない
（`matched>0`でも本文に無関係な可能性がある）ため、必ず本文grepと併用する。

```
$ grep -rn '優先順位' .claude/docs .claude/rules
（4件ヒット。内訳: shell-script-style.md「パラメータ展開の既定値」節見出し内の言及1件
（patsub_replacementの話で無関係）、他3件もjqの`\|`と`or`/`,`の優先順位関係を扱ったものは無い）

$ grep -rn 'grep -o' --include='REVIEW-POINTS*.md' --exclude-dir=.gemini .
（ルート・.claude/・wip/plans/のREVIEW-POINTS.mdにヒットなし。wip/reports/REVIEW-POINTS.mdには
`grep -o`の使用例が3箇所あるが、いずれも「値の一覧を目視で確かめる」用途であり、
非0終了・pipefailの罠そのものは扱っていない）
```

`matched=0` かつ `grep` も0件、の組み合わせは今回無かった（`優先順位`は他DDRで3件・`grep`は
14件ヒットする）が、いずれも**该当する罠そのものを扱った記述ではない**ことを本文レベルで
確認した。

**段階3（直近10件のマージ済みPR）**: `mcp__github__list_pull_requests`（state=closed,
sort=updated, perPage=10）でタイトルを確認したが、jq演算子優先順位・grep終了コードに関連する
ものは無かった（#193 #206 #199 #195 #204 #196 #194 #187 #192 #188）。

→ **3項目とも痕跡なしとして確定。反映する。**

### 手順4: 反映先の形態

| 項目 | 反映先 | いつ効くか × 守らせ方の強さ | 削除・統合の検討 |
|---|---|---|---|
| jqの`\|`優先順位（1・2統合） | `.claude/rules/shell-script-style.md`「JSON操作」節 | セッション開始時に常時読込（読ませる）。既存の同節の他jqの罠（`\|`での`.`束縛、`//`のfalsy化）と並ぶ性質の情報で、専用の新節を作るほどの分量ではない | 既存項目との統合は無し（既存3項目とは別トピック）。削除対象の既存記述も無い |
| `grep -o`のpipefail依存中断（3） | `.claude/rules/shell-script-style.md`「エラー方針」節 | 同上。同節は既にpipefailの仕組み自体を説明しており、`grep`の終了コードとの組み合わせもここへ置くのが自然（JSON操作節はjq専用のため不適切） | 統合・削除対象なし |

いずれも常時読込ルール（`.claude/rules/`）へ追記する。より強い守らせ方（hookでの機械的検出等）は
検討したが、シンタックスの罠であり実行時に誤検知なく機械判定するのが難しいため見送る
（既存の同種の罠——`//`のfalsy化、`.`の束縛——もいずれも記述のみで対応している）。

## 反映内容（flow-id 4-6で行う）

### 追記1（「JSON操作」節。既存の`//`falsy化の項の直後、節の末尾）

```markdown
- **jqの`\|`（パイプ）は、`or`/`and`や`,`（カンマ）を含む他のほぼ全ての演算子より優先順位が
  低い。** `A or B \| C`は`A or (B \| C)`ではなく`(A or B) \| C`と、`X \| Y, Z`は
  `(X \| Y), Z`ではなく`X \| (Y, Z)`と解釈される（issue #151で2回実際に踏んだ。jq 1.7で実測）。
  - **実例1（`,`との組み合わせ）**: `map([.[0].message.content\|type, length])`と書いたところ、
    `[.[0].message.content \| (type, length)]`と解釈され、2要素目が「グループの件数」ではなく
    「content自体の文字数」になっていた。気づけたのは合計が既知の値と一致しなかったから。
  - **実例2（`or`との組み合わせ）**: `type == "object" or has("counts") \| not`を
    「`(type=="object") or (has("counts")\|not)`」の意図で書いたところ、実際には
    `(type=="object" or has("counts")) \| not`と解釈され、`has("counts")`が真のとき常に偽を
    返す（意図と逆）。
  - **`or`/`and`・`,`と`\|`を1行に混ぜるときは、常に括弧で優先順位を明示する。**

  \`\`\`bash
  # 悪い例（意図: countsがobjectでない、またはcountsキーが無ければ真にしたい）
  jq -n '{counts:[]} | type == "object" or has("counts") | not'
  # 良い例（括弧で優先順位を固定する）
  jq -n '{counts:[]} | (type == "object") or (has("counts") | not)'
  \`\`\`
```

### 追記2（「エラー方針」節。pipefailの説明の後）

```markdown
- **`grep`はマッチ0件で終了コード1を返す。パイプの途中に置くと、`set -e`単体では検知できず
  `pipefail`が立っているときだけ呼び出し元を中断させる**（issue #151で実際に踏んだ）。
  `sentinel="$(printf '%s\n' "$text" \| grep -o 'PATTERN' \| tail -1)"`という形は、`grep -o`が
  パイプの最後ではないため、**`set -e`単体（`pipefail`無し）では`tail -1`の終了コード
  （マッチ0件でも0）だけが見られ、中断しない。一方`set -eo pipefail`配下では、パイプ中の
  どれか1つでも失敗すればパイプ全体が失敗として扱われ、`grep -o`のマッチ0件がそのまま
  関数呼び出し元を無言で中断させる**（実測: `set -e`単体では生存しrc=0、`set -eo pipefail`では
  中断しrc=1）。呼び出し元が`set -e`のみか`pipefail`も併用するかは、その関数が将来どこから
  呼ばれるかに依存し予測できない。**`grep`をパイプの途中に含む処理は、呼び出し元の
  `pipefail`設定に依存せず安全にするため、常に`\|\| true`を添える。**

  \`\`\`bash
  # 悪い例（set -eo pipefail配下でマッチ0件のとき無言で中断する）
  sentinel="$(printf '%s\n' "$text" | grep -o 'PATTERN' | tail -1)"
  # 良い例
  sentinel="$(printf '%s\n' "$text" | grep -o 'PATTERN' | tail -1 || true)"
  \`\`\`
```

## やらないこと（スコープ外）

- **isSidechain false-as-falsy回帰の教訓** は、既にflow-id 3-6実装時（本MRの`ai-asset`コミット）
  に「JSON操作」節へ反映済み。本計画の対象外（重複反映を避ける）。
- **過去MRの遡及調査**: 今回の3つの入力（worklog全6本・reports・レビューコメント）で知見が
  出揃っているため行わない（`references/planning.md`「過去のMRを遡らない」）。
- **hookによる機械的検出**: 上記「手順4」のとおり、シンタックスの罠のため見送る。

## 検証

```bash
# 1. 追記する主張そのものが正しいことを実行して確かめる（jq 1.7で実測済み。反映後に再実行）
jq -n '{counts:[]} | type == "object" or has("counts") | not'          # => false（悪い例）
jq -n '{counts:[]} | (type == "object") or (has("counts") | not)'      # => true（良い例）

# 2. grep -oのpipefail依存中断を実行して確かめる
bash -c 'set -e;        f(){ local s; s="$(printf "no match\n" | grep -o "XYZ" | tail -1)"; echo "reached rc=$?"; }; f'          # 生存（rc=0）
bash -c 'set -eo pipefail; f(){ local s; s="$(printf "no match\n" | grep -o "XYZ" | tail -1)"; echo "reached rc=$?"; }; f' ; echo "outer=$?"  # 中断（outer=1）

# 3. 追記が入ったことを、変更前に0件だった語で確認する（該当語は手順3「痕跡の確認」で実測済み）
grep -c '優先順位' .claude/rules/shell-script-style.md   # 反映前0 → 反映後1以上
grep -c 'pipefail.*grep\|grep.*pipefail' .claude/rules/shell-script-style.md  # 反映前0 → 反映後1以上

# 4. frontmatterのキー構成が変化しないこと（既存キーの下に追記するだけ）
bash .claude/scripts/src/extract-frontmatter.sh .
```

合格条件: 検証1・2の実行結果が、追記した「悪い例」「良い例」の説明と一致すること。検証3が
反映前後で変化すること（反映前0件・反映後1件以上）。検証4でfrontmatterのキー構成に変化が
無いこと。
