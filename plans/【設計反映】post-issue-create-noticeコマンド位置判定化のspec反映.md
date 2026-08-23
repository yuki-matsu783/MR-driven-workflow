---
title: 【設計反映】post-issue-create-notice.shコマンド位置判定化のspec反映
type: plan
description: issue #149の実装内容をcommand-position.md・issue-mr-workflow.mdへ反映し、DDR i0149-01を新設する個別反映計画
tags: [hook, command-position, issue-149, spec反映]
keywords: [command_invokes_script, CommandPosition, spec反映, DDR, 既知の制約, 遅延初期化]
---

# 【設計反映】post-issue-create-notice.shコマンド位置判定化のspec反映

対象: issue #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす。
フェーズ4〈反映〉flow-id 4-1。

## 前提（合意状況）

- 個別作業計画（`plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`）
  はflow-id 3-3/3-4でユーザーの承認を得た（チャット上の「レビュー済み」。PRレビュースレッド0件を
  MCPで確認済み）。
- 実装結果（`reports/20260823_post-issue-notice-command-position_実装結果.md`）は
  flow-id 3-6〜3-9ループの1周目で完了し、同じく承認済み。敵対的レビューを計画時1回・実装後2回
  （計3回、うち実装後2回はいずれも指摘を反映済み）実施した。

## 敵対的レビュー（1回目・計画レビュー）を踏まえた改訂

初版はcommand-position.mdの4箇所・issue-mr-workflow.mdの1箇所のみを対象としていたが、
敵対的レビューで13件の指摘（blocker 1件・major 8件・minor 3件・nit 1件）を受け、下表のとおり
対応した（DDR新設の要否も含め、実装済みコードとの突き合わせで判明した反映漏れが中心）。

| # | 重大度 | 指摘 | 対応 |
|---|---|---|---|
| 1 | major | 計画md自身にfrontmatterが無い | 本ファイル冒頭へ追加（本改訂で対応済み） |
| 2 | blocker | issue-mr-workflow.md「検知の条件」表のCLI行・`is_issue_create_call`の説明が、コマンド位置判定への移行前の記述のまま | 変更対象へ追加（下記） |
| 3 | major | command-position.md「呼び出し側（hook）の責務」節が、3段ガードの型が2種類あることを説明していない | 変更対象へ追加 |
| 4 | major | 「判定の3段」の相違点が§3のみでは不十分（§1事前チェック・§4保守的フォールバックもgit版と異なる） | §1・§4も対比対象に追加 |
| 5 | major | インタプリタ経由の実行を**肯定的に検知する**経路（script版の主検知経路）が相違点リストに無い | 相違点リストの先頭項目として追加 |
| 6 | major | 新しい既知の制約（クォートパス保守的フォールバック化・過検知の残存）は「未決定事項」ではなく「既知の制約」表へ書くべき | 反映先を「既知の制約」表へ変更 |
| 7 | major | 「前置フィルタが新判定本体に対しても超集合か」というcommand-position.md側の申し送りへの回答が計画に無い | 未決定事項の書き換えへ回答を含める旨を追記 |
| 8 | minor | command-position.mdのfrontmatter（description/keywords）が更新対象に入っていない | 変更対象へ追加 |
| 9 | major | DDR新設の要否が計画に無い（同系列のissue #53・#159はいずれもDDRを残している） | `i0149-01`を新設する（下記） |
| 10 | major | 「AIアセット反映は無い」の判断根拠が弱い（`.claude/rules/`に今回で古くなる記述がある） | `shell-script-style.md`の該当箇所を確認し反映対象へ追加（下記「AIアセット反映」） |
| 11 | minor | command-position.md「影響範囲」節にissue #149のエントリが無い・単体テスト行の更新漏れ | 変更対象へ追加 |
| 12 | minor | 検証コマンドが「反映されたこと」を判定できない（既存ヒットと区別できない等） | 検証コマンドを書き直す（下記「検証」） |
| 13 | minor | md/htmlの内容が同期していない | 本改訂で同期させる |
| 14 | nit | `CommandPosition.sh`のコメント誤字（「まえ」→「まで」） | spec反映時に正しい表現で転記する（コード自体の誤字修正は別途判断。下記「やらないこと」） |
| 15 | nit | レビュー呼び出し時に観点表が未展開の文字列のまま渡っていた | 今回のレビュー自体は一般観点で実施済みのため計画への影響なし。次回以降の呼び出し方法の改善事項として記録（HANDOFF.mdへ記載） |

**「既知の制約」表 vs 「未決定事項」の使い分け（指摘6）**: command-position.mdの`## 既知の制約`
表は「決着済みで受け入れた制約」を、`## 未決定事項・懸念点`は「まだ結論が出ていないこと」を
それぞれ扱う。クォートパスの保守的フォールバック化・PowerShellバックスラッシュパス・opaque語
フォールバックによる過検知は、いずれもissue #149の敵対的レビュー2回目で実機確認・受容済みの
**決着済みの制約**であるため、表側へ追加する。「未決定事項・懸念点」側は、
`post-issue-create-notice.sh`への適用状況の更新（適用済みへの書き換え）と、前置フィルタの
超集合性を再確認した結果（指摘7の回答）に限定する。

## この計画で何をするか

`.claude/hooks/lib/CommandPosition.sh` / `.claude/hooks/post-issue-create-notice.sh` へ加えた
issue #149の実装内容を、恒久ドキュメント（`.claude/docs/spec/`）・DDR・一部のAIアセット
（`.claude/rules/`）へ反映する。実装コード・テストコードの追加修正は無い（フェーズ3のレビュー
往復ループで解消済みのため`【実装反映】`は対象外。本計画は`【設計反映】`と、副次的に判明した
`【AIアセット反映】`を扱う）。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/spec/command-position.md` | 変更 | 「利用元」・「公開インターフェース」表・「判定の3段」§1/§3/§4・「呼び出し側（hook）の責務」節・「既知の制約」表（3行追加）・「未決定事項・懸念点」の書き換え・「影響範囲」changelogエントリ追加・frontmatter（description/keywords） |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「検知の条件」表のCLI行・判定説明の書き換え、「既知のトレードオフ」節への追記 |
| `.claude/docs/ddr/i0149-01-post-issue-create-notice.shの検知をコマンド位置判定へ移行する.md` | 新規 | issue #149の設計判断（sticky解除・`{`/`}`除外・3段ガード遅延初期化・保守的フォールバック踏襲）と却下案を記録（敵対的レビュー2回目でファイル名をtitleへ合わせて改名） |
| `.claude/docs/README.md` | 変更 | `generate-ddr-list.sh`実行によるDDR一覧の差分反映（DDR新設に伴う機械的な追随） |
| `.claude/rules/shell-script-style.md` | 変更 | `[[ "$command" == *create-issue.sh* ]]`をCR非依存の実例として挙げている箇所に、issue #149後は縮退経路限定である旨を追記（下記「AIアセット反映」） |
| `.claude/hooks/lib/CommandPosition.sh` | 変更（コメントのみ） | 615行目コメントの誤字「まえ」→「まで」を修正（指摘14。実装ロジック自体は無変更） |

## 方針

### command-position.md

1. **冒頭「利用元」**: `post-issue-create-notice.sh`を追加する（現在は
   `block-direct-git-commit.sh` / `post-push-usage-report.sh` / `post-push-compact-prompt.sh`
   の3本のみ）。ただしこのhookは`command_invokes_git_subcommand`ではなく新設の
   `command_invokes_script`を使うため、「（`command_invokes_script`経由。下記「公開インター
   フェース」参照）」の注記を添える。

2. **「公開インターフェース」表**: `command_invokes_script <コマンド文字列> <対象スクリプト名>`
   の行を追加する。既存の`command_invokes_git_subcommand`の行と対で並べ、「gitサブコマンド固定の
   判定」対「任意のスクリプトbasenameの判定」という役割の違いが分かるようにする。

3. **「判定の3段」§1（事前チェック・縮退）**: 現在の記述は「従来の部分一致で判定する」とだけ
   書き、暗黙にgit版の`[[ "$lower" =~ git[[:space:]]+${sub,,} ]]`を前提にしている。script版の
   縮退判定式（`[[ "$lower" == *"$script_lower"* ]]`。スクリプト名の単純部分一致）は異なるため、
   「判定式はサブコマンド固定か任意のスクリプト名かで異なる」旨を追記する。

4. **「判定の3段」§3（コマンド位置でのトークン走査）**: `_cp_scan_tokens_for_script`との
   相違点を、**インタプリタ経由の肯定的検知（主検知経路）を先頭に**して追記する（指摘5）。
   - **インタプリタ経由の起動（`bash <path>` 等）を1トークン先読みして肯定的に検知する**
     （`create-issue.sh`は実際に`bash .claude/scripts/src/create-issue.sh …`で起動されるため、
     本hookの主検知経路である）。ただし`_CP_CODE_OPTS`（`-c`等）が挟まる場合は保守的
     フォールバックへ回り、シェル系インタプリタ＋`_CP_NONEXEC_OPTS`（`-n`）の場合は非検知、
     直後の引数がクォート等でプレースホルダに潰れている場合は保守的フォールバックへ回る。
     git版にはこの肯定的検知経路自体が無い（`bash`を見た時点で`-c`系の有無だけを見る）。
   - `_CP_PREFIX_WORDS`通過後の挙動: git版は次のセパレータまでコマンド位置を保つ（sticky）のに
     対し、script版は「次の非オプション・非代入トークンを実コマンドとして1回だけ判定し、
     そこでコマンド位置を終える」（sudo/timeoutの引数に無関係なコマンドが現れるだけの
     誤検知を避けるため）。
   - `{`/`}`のトークン化: git版は人工的な空白挿入の対象に含めるが、script版は除外する
     （`${VAR}/path`のようなパラメータ展開直後の誤検知を避けるため）。
   - 値を取るprefixオプション（`_CP_PREFIX_OPTS_WITH_VALUE`）と、最初の非オプション引数が
     値であるprefix語（`_CP_PREFIX_WORDS_WITH_LEADING_VALUE`。`timeout`）は、script版のみが
     持つ（git版の`_CP_GIT_OPTS_WITH_VALUE`と同種だが対象が異なる）。

5. **「判定の3段」§4（保守的フォールバック）**: `_CP_OPAQUE_WITH_OPT`について、script版は
   git版の「`_CP_CODE_OPTS`併用時のみ」に加え、(a) 直後の非オプション引数が対象スクリプトなら
   その場で肯定的に一致（上記4の主検知経路。§3で説明済みなのでここでは相互参照に留める）、
   (b) その引数がプレースホルダ`_`（クォート由来）なら`_CP_OPAQUE_FOUND`を立てて保守的
   フォールバックの対象にする、という2点を持つことを追記する。

6. **「呼び出し側（hook）の責務」節**: 3段ガードには2つの型があることを追記する。
   (a) `block-direct-git-commit.sh`型: `declare -F command_invokes_git_subcommand`を確認し
   `main()`内・前置フィルタの後で確定させる。(b) `post-issue-create-notice.sh`型:
   `declare -F command_invokes_script`を確認するが、**初回呼び出しまで初期化（`source`・
   バージョン確認）を遅延させ、自分自身を確定版へ再定義してから委譲する**。(b)を採る理由
   （前置フィルタで弾かれる呼び出しでも約800行のライブラリを毎回読み込むと、フィルタ済みの
   高速経路で計測上+35%/+1.0msの遅延が生じ、issue #159の最適化を一部無言で戻すため）を書く。

7. **「既知の制約」表へ3行追加**（指摘6。表の列: 類型／例／挙動／扱い）:
   - クォートで囲まれたスクリプトパス（`bash "$VAR/create-issue.sh"`） / 位置判定では追えないが
     インタプリタ直後の引数がプレースホルダの場合は保守的フォールバックで拾う / 安全側
     （見逃しにくくなる方向）
   - PowerShell経路でのバックスラッシュ区切りパス（`.claude\scripts\src\create-issue.sh`） /
     素通り（見逃し） / 安全側（`command_invokes_git_subcommand`も共有する既存の制約）
   - opaque語（`find`/`xargs`/`ssh`/`watch`/`flock`）がコマンド位置にある場合の保守的
     フォールバック / 対象語を引数に含むだけの検索コマンド等でも発火（過検知） / 意図的
     （ブロックではなく注意喚起の注入に留まる本hookでは実害が限定的）

8. **「未決定事項・懸念点」の書き換え**（指摘7の回答を含める）: `post-issue-create-notice.sh`
   の判定本体に「適用していない」旨の既存段落を、次の内容へ書き換える。
   - issue #149でCLI経路を`command_invokes_script`へ移行済み（実装・検証結果へのリンク）。
   - **前置フィルタ（`raw_hints_at_issue_create`）の超集合性の再確認結果**: 新判定本体
     （コマンド位置判定＋script版の縮退判定式）に対しても引き続き超集合であることを確認した
     （根拠: 前置フィルタの正規化＝バックスラッシュ除去・大文字小文字非依存の比較は判定本体の
     入力形式を狭めない設計のままであり、`test_post_issue_create_notice.sh`の前置フィルタ
     ケース群が変更後も全件通過している）。
   - 残る既知の制約・過検知は「既知の制約」表（上記7）へ移したため、ここでは繰り返さない。

9. **「影響範囲」節へ`### issue #149（追加）`エントリを新設**（指摘11）: 新規追加した2関数
   （`_cp_scan_tokens_for_script`/`command_invokes_script`）・差し替えた`post-issue-create-notice.sh`
   ・追加した単体テスト件数（`test_command_position.sh`+33件・`test_post_issue_create_notice.sh`
   +7件）を書く。過去の`### issue #53（新規作成）`エントリは変更しない。

10. **冒頭「単体テスト」行**: `test_post_issue_create_notice.sh`（3段ガード縮退経路のテストを
    含む）も併記する。

11. **frontmatter**: `description`を「gitのサブコマンド／任意のスクリプトが…」へ広げ、
    `keywords`に`command_invokes_script`・`スクリプト実行判定`を追加する（指摘8）。

### issue-mr-workflow.md

1. **「検知の条件」表のCLI行を書き換える**（指摘2・blocker）。現在の「コマンド文字列に
   `create-issue.sh`を含む」を、「`command_invokes_script`によるコマンド位置判定
   （ライブラリを使えない場合のみ部分一致へ縮退。詳細: `command-position.md`）」へ書き換える。
   直後の「判定は純粋関数`is_issue_create_call`に切り出してあり」の説明も、実体が`_pin_cli_match`
   （3段ガード・遅延初期化）への委譲になった点を反映する。この書き換えは point-in-time
   の記録ではなく**現在の仕様を説明する節**の更新であり、`.claude/rules/docs-workflow.md`の
   「changelogは書き換えない」原則には抵触しない（抵触するのは下記2の追記対象である
   「既知のトレードオフ」節の`追記（issue #53）`ブロックの方で、そちらは追記に留める）。

2. **「既知のトレードオフ」節への追記**（issue #39実装時点の記述の末尾、issue #53実装時に
   追記された「issue #149として起票済み」という既存の追記の**続き**として書く。過去の
   changelogエントリ自体は変更しない）。
   - `command_invokes_script`による判定への差し替えが完了したこと。
   - 3段ガードの遅延初期化（詳細は`command-position.md`「呼び出し側（hook）の責務」への
     リンクに留め、重複を避ける）。
   - 残る既知の制約・過検知は`command-position.md`「既知の制約」表へのリンクに留める
     （指摘6と同じ理由で、詳細の二重管理を避ける）。

### DDR新設（`i0149-01`）

issue #149では、却下案を伴う意思決定が複数あった（個別作業計画「敵対的レビュー（1回目）を
踏まえた設計改訂」節・worklogに記録済み）。同系列の変更（issue #53・#159）がいずれもDDRを
残している慣行に合わせ、`i0149-01`を新設する（指摘9）。記録する決定は次の4点。

1. `_CP_PREFIX_WORDS`通過後を、git版のsticky（次のセパレータまでコマンド位置を保つ）ではなく
   「次の非オプション・非代入トークンを1回だけ判定」にした（却下案: git版と同じsticky設計→
   `sudo cat <path>`等で誤検知するため却下）。
2. `{`/`}`を人工的な空白挿入の対象から除外した（却下案: git版と同じく含める→
   `${VAR}/path`直後で誤検知するため却下）。
3. 3段ガードの初期化を初回呼び出しまで遅延させた（却下案: トップレベルで`source`まで完了させる
   →前置フィルタで弾かれる呼び出しでも毎回ライブラリを読み込み+35%の遅延が生じるため却下）。
4. インタプリタ経由の肯定的検知＋クォート引数の保守的フォールバックを採用した（却下案:
   クォートパスは見逃したままにする→旧・部分一致実装に対する機能後退になるため却下）。

新設後、`bash .claude/scripts/src/generate-ddr-list.sh`を実行し、`.claude/docs/README.md`の
DDR一覧の差分を同じコミットへ含める（`.claude/rules/markdown-frontmatter.md`「DDRの識別子」・
`.claude/rules/docs-workflow.md`の規約どおり）。

### AIアセット反映（`.claude/rules/shell-script-style.md`）

577行目の「複数行になりうるが判定にしか使わない値は例外」の実例リストが、
`[[ "$command" == *create-issue.sh* ]]`という**部分一致を`post-issue-create-notice.sh`の
現在の判定として**挙げている。issue #149以後はこの形が通常経路ではなく**縮退時のフォールバック
にのみ残る**ため、直後の「issue #53で判定がコマンド位置ベースへ変わったが、`tr -d '\r'`が不要
という結論は変わらない」という既存の追記パターンと同じ形で、`create-issue.sh`の例についても
同様の注記を追加する（指摘10）。`ai-command-style.md`の「対象のhook」表は、**この計画では
更新しない**（下記「やらないこと」参照）。

## やらないこと（スコープ外）

- **実装コード・テストコードの追加修正**: フェーズ3のレビュー往復ループ（3-6〜3-9）で
  すべて解消済みのため、`【実装反映】`計画は作らない。`CommandPosition.sh`のコメント誤字
  修正（指摘14）のみ、ロジック無変更の範囲で本計画に含める。
- **`.claude/settings.json`の`if`フィルタの変更**: command-position.md「未決定事項・懸念点」
  が既存の未決定事項として持っており、issue #149のスコープ外（issue #47が両論併記のまま
  残している）。
- **`.claude/rules/ai-command-style.md`「対象のhook」表への`post-issue-create-notice.sh`追加**
  （指摘10の一部）: 同表は`git`と`commit`/`push`という**2語の連続**を避ける技法を説明しており、
  `create-issue.sh`は単一トークンのため同じ技法（語を分割して書く）が成立しない。誤って表へ
  加えると、存在しない回避策があるかのように読める。`shell-script-style.md`側の注記
  （上記「AIアセット反映」）で必要な情報は足りると判断する。
- **`.claude/docs/README.md`のspec一覧に`command-position.md`自体を追加すること**
  （指摘11の派生。README一覧に元々`command-position.md`が載っていない欠落はissue #53時点から
  存在し、issue #149に起因しない）: 本issueのスコープ外の既存ギャップであり、混ぜて直すと
  差分の見通しが悪くなる。気づいた事実としてHANDOFF.mdへ記録し、別途判断してもらう。

## 検証

```bash
# command-position.mdの反映内容ごとに、期待する記述が入っていることを個別に確認する
# （既存ヒットと区別するため、単純なgrepの有無ではなく反映後に増える行数で判定する）
grep -c 'command_invokes_script' .claude/docs/spec/command-position.md   # 反映前2 → 反映後4以上
grep -c '既知の制約' .claude/docs/spec/command-position.md               # 表の行数が3行増える
grep -n '### issue #149' .claude/docs/spec/command-position.md          # 影響範囲へのエントリ追加を確認

# issue-mr-workflow.mdの「検知の条件」表が書き換わったことを確認する
grep -n 'command_invokes_script' .claude/docs/spec/issue-mr-workflow.md

# DDR新設・一覧再生成の確認
ls .claude/docs/ddr/i0149-01-*.md
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat .claude/docs/README.md

# frontmatterが再インデックスされることを確認する（実インデックス生成）
bash .claude/scripts/src/extract-frontmatter.sh .
bash .claude/scripts/src/search-frontmatter.sh --keyword command_invokes_script 2>/dev/null || true

# 過去のchangelogエントリ・DDR本文を書き換えていないことを確認する（分岐点との差分の削除行）
git diff <ブランチ分岐点> -- .claude/docs/ | grep -E '^-[^-]' || echo '削除行なし'

# コード側の変更が誤字修正のみであることを確認する（ロジックは無変更）
bash -n .claude/hooks/lib/CommandPosition.sh
bash .claude/scripts/test/test_command_position.sh
bash .claude/scripts/test/test_post_issue_create_notice.sh
```

合格条件: 上記のすべての反映箇所（command-position.md 9箇所・issue-mr-workflow.md 2箇所・
DDR新設1件・README.md自動反映・shell-script-style.md 1箇所・CommandPosition.shのコメント誤字
1箇所）が確認でき、過去のchangelogエントリ・DDR本文の削除行が無く、単体テスト2本が
`failures=0`のままであること。

## 比較検討した案

| 案 | 利点 | 採否と理由 |
|---|---|---|
| `【設計反映】`と`【実装反映】`を1ファイルへ併記する | ファイル数が減る | 却下。実装修正が無いため`【実装反映】`自体が不要。1ファイルにしても評価軸が増えない一方、`docs-workflow.md`の既定（基本的に分ける）から外れる理由が無い |
| command-position.mdの反映箇所をまとめて1つの節に追記する | 編集箇所が減る | 却下。「既知の制約」「判定の3段」「公開インターフェース」等はそれぞれ読み手の関心が異なる既存節であり、まとめると該当箇所を探しにくくなる |
| DDRを新設しない（実装コメント・worklogのみに留める） | 作業量が減る | 却下。worklogはflow-id 5-4で削除され、実装コメントは「なぜ」までは説明するが却下案の比較までは残らない。同系列issueの慣行（i0053-01・i0159-01）とも整合しない |
| `ai-command-style.md`の対象hook表へ`post-issue-create-notice.sh`を追加する | 表の網羅性が上がる | 却下（上記「やらないこと」参照）。単一トークンの対象には同表の技法が成立しないため、誤った回避策があるように読める |
