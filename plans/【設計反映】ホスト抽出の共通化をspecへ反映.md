# 【設計反映】ホスト抽出の共通化をspecへ反映

対象issue: [#55](https://github.com/yuki-matsu783/MR-driven-workflow/issues/55)
全体作業計画: `plans/mutable-beaming-leaf.md`
実装の記録: `worklog/20260819_mutable-beaming-leaf_【実装】【テスト】ホスト抽出の共通化_push1.md`

`【AIアセット反映】` とは分けて実施する（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する
場合／分ける場合」。正史ドキュメントへの記録と運用ルールの改訂は評価軸が異なるため）。本計画を
先に完了・レビューしてから `【AIアセット反映】` へ着手する。

## 変更対象

| ファイル | 節 | 内容 |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 「提供関数」表**直後**の段落 | `split_remote_url` を内部ヘルパーとして追記し、`provider_from_remote_url` の説明を新しい関係へ更新 |
| 同上 | 「決定済み事項（旧・未決定事項）」 | `parse_repo_slug` のホスト小文字化を1項目として追加 |
| 同上 | 「影響範囲」 | **新規エントリを末尾へ追記**（過去エントリは書き換えない） |

**DDRは新規作成しない。** 判断の根拠は後述「DDRを作らない理由」。

## 1. 「提供関数」表直後の段落を更新する

現状、この段落は「`Provider.sh` 内にありながら上表に載らない内部実装」の例として
`provider_from_remote_url` を挙げている。ここに `split_remote_url` を加える。

**追記する内容（要旨）**

- issue #55で `split_remote_url` を追加した。remote URLを「ホスト部（`REPLY_HOST`）」と
  「パス部（`REPLY_PATH`）」へ分解するパラメータ展開のみの純粋関数で、`provider_from_remote_url`
  （ホスト部のみ使用）と `parse_repo_slug`（両方使用）の共通の土台になっている。
  これも上表には載らない内部ヘルパーである。
- **結果を標準出力ではなくグローバル変数（`REPLY_HOST` / `REPLY_PATH`）へ返している理由**を書く。
  標準出力にすると呼び出し側がコマンド置換を強いられ、`provider_from_remote_url` の「1回あたりの
  プロセス起動ゼロ」（DDR 0028の制約。12個のディスパッチャが `case "$(get_provider)" in` の形で
  呼ぶためメモ化が効かない）を壊すため。**関数呼び出しはコマンド置換ではないのでforkは増えない。**
- **ホスト名が空でも失敗させない**設計であることを書く。エラーにするかを呼び出し側の判断に委ねる
  ことで、`provider_from_remote_url`（終了コード1）と `parse_repo_slug`（空のままJSONを返す）
  それぞれの従来の振る舞いを変えずに済んでいる。

`provider_from_remote_url` に関する既存の記述（純粋関数であること・`get_provider` が薄いラッパー
であること・単体テスト可能にするための切り出しであること）は**そのまま残す**。「ホスト抽出を
自前で行っている」と読める箇所だけを、`split_remote_url` へ委譲している形へ改める。

**「提供関数」表そのものは変更しない**（`split_remote_url` は公開インターフェースではないため、
表に行を追加しない。これは同段落が明示している「上表に載るのは呼び出し側が直接使う関数のみ」という
方針そのものに従う）。`parse_repo_slug` の行も、返すJSONのキー・構造が変わっていないため変更不要。

## 2. 「決定済み事項」へホスト小文字化を追加する

issue #55の受け入れ条件「外部から見た振る舞いが変わる場合はspecへ記録する」に直接対応する項目。
既存項目の書式（`- **（issue #NN）見出し**: 本文`）に合わせて末尾へ追加する。

記載する内容:

- **何が変わったか**: `parse_repo_slug` が返す `.host` と `.url` のホスト部を小文字化するように
  なった（`https://GitHub.COM/O/R.git` → `.host` が `github.com`、`.url` が `https://github.com/O/R`）。
  従来は入力の大文字小文字をそのまま返していた。
- **なぜ許容するか**: ホスト名はDNS上case-insensitiveであり、小文字化はURLの正規化として安全。
  `provider_from_remote_url` は元々小文字化しており、共通化にあたり**挙動の緩い側ではなく
  正規化する側へ揃えた**。
- **何が変わっていないか**: `.owner` / `.repo` / `.path` は小文字化しない。リポジトリ名・
  ネームスペース名の大文字は保たれる（GitHub/GitLabともパス部はcase-sensitiveに扱われうるため）。
- **消費側への影響**: `.claude/hooks/session-start.sh` と `get_repo_url` はいずれも
  `.owner` / `.repo` / `.url` しか使わず、実リポジトリのホストは元々小文字のため影響なし。
- **どう固定したか**: `tests/test_vcs_provider.sh` に
  「ホストは小文字化・パスは保つ」ケースを明示的に追加した。

## 3. 「影響範囲」へ新規エントリを追記する

既存の最終エントリ（`変更（追加分・issue #45 get_providerのホスト判定化）:`）の**後ろへ**、
同じ書式で新しい見出しと箇条書きを足す。**過去のエントリは1行も書き換えない**
（`.claude/rules/docs-workflow.md`: 過去issueごとのchangelogはpoint-in-timeの記録）。

```
変更（追加分・issue #55 remote URLのホスト抽出の共通化）:
- `.claude/scripts/src/vcs/Provider.sh`
  - `split_remote_url` を純粋関数として新設（... REPLY_HOST / REPLY_PATH へ返す。fork ゼロ）
  - `provider_from_remote_url` をホスト抽出のみ委譲する形へ変更（判定規則・エラーメッセージ・
    終了コードは変更なし。1回あたりのプロセス起動ゼロを維持）
  - `parse_repo_slug` から `sed` 2回を除去（外部プロセス起動 3回 → 1回。実測 415ms/回 → 105ms/回）。
    返すJSONのキー・構造は変更なし。ホストを小文字化するようになった点のみ振る舞いが変わる
- `tests/test_vcs_provider.sh`（`split_remote_url` の単体テストを8件追加。既存36件は無変更。
  `passed=44 failures=0`）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表直後の段落へ
  `split_remote_url` を追記、「決定済み事項」へホスト小文字化を追加、本エントリを追加）
```

新規ファイルは無いため `新規（追加分・...）:` の見出しは作らない。

## DDRを作らない理由

DDR 0028が「プロバイダ判定はremote URLのホスト部で行う」という判定規則と、「`provider_from_remote_url`
は1回あたりのプロセス起動をゼロに保つ」という制約の**両方を既に記録している**。本issueは、その
制約を守ったまま重複実装を1箇所へ寄せた内部整理であり、**新しい意思決定を含まない**。

`REPLY_HOST` / `REPLY_PATH` というグローバル変数経由の戻り値も、
`.claude/rules/shell-script-style.md`「ホットパスの小さなヘルパー関数は…`REPLY` へ返す」という
既存ルールの適用であって、新規の設計判断ではない。

ホストの小文字化だけは外部から見た振る舞いの変更にあたるが、これは**採用/却下を比較検討した
意思決定というより、統合に伴い一方へ揃えた帰結**であり、specの「決定済み事項」に1項目として
残せば追跡には十分と考える。レビューで「DDRとして残すべき」と判断された場合は作成する。

## やらないこと

- 「提供関数」表への行追加（`split_remote_url` は公開インターフェースではない）。
- 過去のchangelogエントリ（「影響範囲」の既存項目）の書き換え。
- DDR 0027・0028の変更（frontmatterを含め、`status` を付ける必要も無い。0028は現在も有効）。
- 「コンポーネント構成」節の `Provider.sh` 説明の書き換え（判定規則自体は変わっておらず、
  `provider_from_remote_url` に切り出してあるという記述も引き続き正しいため）。
- `.claude/docs/README.md` の更新（DDRを追加しないため）。

## 検証手順

1. 追記後に `bash .claude/scripts/src/extract-frontmatter.sh .` が正常終了すること
   （frontmatter自体は変更しないが、markdownの構造を壊していないことの確認を兼ねる）。
2. 「影響範囲」の**過去エントリに差分が出ていない**ことを `git diff` で目視確認する
   （追記のみで、既存行の変更が0行であること）。
3. 記載したパス・関数名・数値（415ms → 105ms、`passed=44 failures=0`、fork 3→1）が
   worklogの実測値と一致していること。
