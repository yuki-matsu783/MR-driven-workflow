---
title: i0070-01. .gemini/配下は.claude/からの変換生成物にしGit管理下へ置く
type: ddr
description: .gemini/をローカルリンク運用から.claude/の変換生成物へ改め、記法差をsync-gemini-assets.shが吸収する方式を採用した経緯と、リンク運用の継続・配布物として配る案を却下した理由を記録したDDR
tags: [ddr, gemini, sync, generation]
keywords: [sync-gemini-assets, setup-gemini-links, シンボリックリンク, 記法差, agentLoader, strict, policy-engine, 却下案, i0000-13]
---

# i0070-01. `.gemini/` 配下は `.claude/` からの変換生成物にしGit管理下へ置く

issue #70

## 背景

`.gemini/` は `settings.json` 以外（`docs/` `hooks/` `rules/` `scripts/` `skills/`）を
`.claude/` 配下へのローカルリンクとして持ち、`setup-gemini-links.sh` が各開発者のマシン上で
生成する設計だった（DDR `i0000-13`）。Gemini CLI と Claude Code でルール・スキルを二重管理
しないための仕組みである。

この前提が2つの点で成り立っていなかった。

1. **リンクでは記法差を吸収できない。** 同じ実体を両方から読ませる方式は、両者が同じスキーマを
   読むことを前提にしている。実際には `agents/*.md` の frontmatter も `settings.json` も
   スキーマが異なる。とくに gemini-cli の `agentLoader.ts` の `localAgentSchema` は
   **`.strict()`** なので、Claude 側の `type` / `tags` / `keywords` が1つ残るだけでロードが失敗
   する。settings も `PreToolUse` → `BeforeTool`、ツール名 `Read` → `read_file` のように
   語彙そのものが違う。
2. **`agents/` がそもそもリンク対象に入っていなかった。** `setup-gemini-links.sh` の `TARGETS`
   は `(docs hooks rules scripts skills)` で、`agents` を含まない。つまりサブエージェント定義は
   Gemini 経路から**一度も見えていなかった**。

加えて、リンクは `.gitignore` 対象のためリポジトリを見ても中身が分からず、配布先でリンク生成を
忘れると Gemini CLI からは資産が1つも見えない。

## 決定

1. **`.gemini/` を「手で書く実体」ではなく「`.claude/` から機械的に決まる生成物」とする。**
   記法差は `.claude/scripts/src/sync-gemini-assets.sh` が変換で吸収する。
2. **生成物だがGit管理下へ置きコミットする**（`.gitignore` から該当9行を削除）。
3. `setup-gemini-links.sh` を削除し、リンク運用を廃止する（DDR `i0000-13` を
   `status: superseded` にする）。
4. 変換は**丸ごと置き換え**とし、`.gemini/` 側の直接編集は認めない。
5. **変換できないものは黙って落とさず、エラーで停止する**か、理由付きの除外リストへ載せる。

用語変換規則・モード・削除ファイル検出の詳細は `.claude/docs/spec/sync-gemini-assets.md` が正である。

## 理由

### なぜ変換なのか（リンク運用の継続を却下した理由）

リンク運用を続けるには、`.claude/` 側を**両者が読める最大公約数**に寄せるしかない。それは
Claude Code 側の資産に Gemini の制約を持ち込むということで、主客が逆転する。とくに
`localAgentSchema` の `.strict()` に合わせるには、`.claude/agents/*.md` から
`.claude/rules/markdown-frontmatter.md` が定めるキー（`type` / `tags` / `keywords`）を
**消さなければならない**。これらは `index.jsonl` の検索キーであり、消せない。

変換方式なら、`.claude/` 側は自分の規約のまま書ける。**制約を持つ側（Gemini）に合わせる処理を、
その側の生成物の中だけへ閉じ込められる。**

### なぜ生成物なのにGit管理下へ残すのか

`index.jsonl` は生成物としてGit管理外にしている（DDR `i0036-01`）が、同じ扱いにすると次が壊れる。

- **配布先でリンク生成（＝再生成）を忘れると、Gemini CLI からは資産がゼロになる。** リンク運用で
  実際に踏みうる失敗であり、これを繰り返さないことが今回の主目的の1つである。
- リポジトリを見ても `.gemini/` に何が入るのか分からない。**変換が正しいかをレビューできない。**

「生成物だからGit管理外」は一般則ではない。**人間やレビューが直接読むかどうか**が分かれ目で、
DDR一覧を生成物のままGit管理下へ残した判断（DDR `i0135-01`）と同じ理由である。

### なぜ配布物として配らないのか

`apply-mr-workflow-to-project` スキルで `.gemini/` を配布アセットに含める案を検討したが、
**配布先で生成する**方を採った。配布物に含めると、配布時点の `.claude/` から作った `.gemini/` が
配布先の `.claude/`（配布先が独自に足したスキル・hookを含む）と食い違う。生成スクリプト自体は
`.claude/scripts/src/` にあるので配布に自動で乗り、配布先で1回流せば済む。

### なぜ「落とさずエラー」なのか

変換先が無いキー・ツール名を黙って落とすと、**Gemini 側が必要な権限や設定を失ったまま
静かに動く**。しかも単体テストは「変換が通った」ことしか見ないので、永久に緑のままになる。
未知の入力で停止させれば、`.claude/` 側へキーが増えた時点で必ず気づく。

実際に issue #103 が `.claude/settings.json` へ `env` を追加した際、この停止が働いて発覚した
（変換先が構造として存在しないため、理由付きで除外リストへ載せて解決した）。

## 却下した案

| 案 | 却下理由 |
|---|---|
| リンク運用を続け、`.claude/` 側を両者が読める形へ寄せる | `.claude/agents/*.md` から `type`/`tags`/`keywords` を消す必要があり、`index.jsonl` の検索が壊れる。Claude 側の規約を Gemini の制約に従わせることになる |
| `.gemini/` を配布アセットに含める | 配布時点のスナップショットが配布先の `.claude/` と食い違う。生成スクリプトは配布に自動で乗るので、配布先で1回流せば足りる |
| 生成物なので `.gitignore` へ入れる | 配布先で再生成を忘れると資産がゼロになる（リンク運用で踏んだ失敗そのもの）。変換結果をレビューできない |
| 変換先の無いキーを黙って落とす | Gemini 側が設定を失ったまま静かに動き、単体テストが永久に緑で通す |
| `.gemini/` を差分更新する | `.claude/` 側で削除・改名されたファイルが残り続ける。丸ごと置き換えのほうが状態が単純で、失われるものは削除ファイル検出で先に見せられる |

## 受け入れた制約

いずれも**外部（Gemini CLI 側）の制約であって、この実装の欠陥ではない**。詳細は
`.claude/docs/spec/sync-gemini-assets.md`「変換しないトップレベルキー」「未決定事項・懸念点」。

- **コミット強制の多重防御が、Gemini 経路では hook 1枚になる。** `permissions` に相当する
  policy engine の Workspace 層が**現在無効**であり（upstream issue #18186）、リポジトリへ
  `.gemini/policies/*.toml` を置いても効果がゼロだからである。**スコープ外なのではなく、今は
  動かない。** 有効化されたら見直す。
- **Gemini CLI 経路では対応工数の OTel 計測が行われない。** Gemini の `settings.json` に環境
  変数を注入するブロックが構造として無く、受け口（`.claude/hooks/otel/listener.pl`）も
  Claude Code の OTel スキーマを前提にしているため。
- **変換後の `.gemini/` を Gemini CLI が実際にロードできることは未確認である。** Gemini CLI が
  この実行環境に無く、変換規則の根拠はすべて gemini-cli のソースコードを読んだものである。
  issue #70 の受け入れ条件のうち、この1点だけが未達のまま残る。
