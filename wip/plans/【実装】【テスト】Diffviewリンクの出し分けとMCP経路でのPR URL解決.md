---
title: 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決
type: plan
description: issue #205 フェーズ3の個別作業計画。get_mr_diff_urlの4引数化・PR URL解決関数の新設・hookの分離配線・テスト追加
tags: [plan, implementation, issue-mr-flow]
keywords: [get_mr_diff_url, git ls-remote, refs/pull, compare_url, diff_url, ディスパッチャ, 経路テスト, Provider.sh, post-push-compact-prompt]
---

# 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決（issue #205 / flow-id 3-1）

- 全体作業計画: `wip/plans/diffview-link-switchover.md`
- 調査結果（この計画の根拠）: `wip/reports/20260824_diffview-link-switchover_調査結果.md`
- PR: #206

## 前提（合意状況）

| 前提 | いつ決まったか | 状態 |
|---|---|---|
| 全体方針3点（純粋関数のまま／MCP経路でも解決を試みる／後退させない） | flow-id 1-4 の全体作業計画 | **人間の合意は未取得**（非対話セッション） |
| 実装する設計4点（下記「実装対象」） | flow-id 2-6 の調査結果 | 敵対的レビュー2回で検証済み。**人間の合意は未取得** |
| GitHubの `/pull/〈n〉/files` というURL形式 | issue #205 本文（リポジトリ所有者が明記） | **ブラウザでの目視確認は未実施**（この環境では不可能） |
| PR URLを `mr_url` へ格納する（スコープの拡大） | flow-id 2-9 の返信で決定 | **人間の承認待ち**。重点レビュー依頼へ記載済み |

**この計画も人間の合意を経ずに進む。** 代わりに、計画作成直後と実装完了直後にそれぞれ
**敵対的レビューを1回ずつ実行**する（ユーザー指示）。

## 種別を併記する理由

`【実装】`と`【テスト】`を併記する。**合意を1回で取る**単位だからである。追加するテストは
実装した関数の振る舞いを固定するもので、実装と切り離して合意を取る余地が無い
（テストだけを先に合意しても、実装の設計が変わればテストも変わる）。

## 実装対象

### 作業1: `get_mr_diff_url` の4引数化

**対象**: `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh` / `Provider.sh`

置き換え前後を両方示す。

```bash
# Github.sh 置き換え前
github_get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3"
  github_get_compare_url "$repo_url" "$base_branch" "$head_branch"
}
# Github.sh 置き換え後
github_get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3" mr_url="${4:-}"
  if [ -n "$mr_url" ]; then
    printf '%s/files\n' "$mr_url"
    return 0
  fi
  github_get_compare_url "$repo_url" "$base_branch" "$head_branch"
}
```

`Gitlab.sh` も同型で、`printf '%s/diffs\n'` にする。

```bash
# Provider.sh 置き換え前
get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3"
  case "$(get_provider)" in
    github) github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" ;;
    gitlab) gitlab_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" ;;
  esac
}
# Provider.sh 置き換え後（第4引数を下位へ渡す）
get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3" mr_url="${4:-}"
  case "$(get_provider)" in
    github) github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" "$mr_url" ;;
    gitlab) gitlab_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" "$mr_url" ;;
  esac
}
```

**制約**:

- **`${4:-}` を使う**（`set -u` 配下で3引数呼び出しが `unbound variable` にならないようにする）。
  既定値に記号を含まないため、`.claude/rules/shell-script-style.md`「パラメータ展開の既定値」の
  バックスラッシュの罠には当たらない。
- **純粋関数のまま保つ。** 関数の中でCLI・API・`git` を呼ばない。
- **`get_mr_diff_since_url` は触らない**（調査結果Q4）。

### 作業2: PR URL解決関数の新設

**対象**: `.claude/scripts/src/vcs/Github.sh`（実装）＋ `Provider.sh`（ディスパッチャ）

```bash
# Github.sh へ新設（純粋関数ではない。git ls-remote を1回起動する）
github_resolve_mr_number_for_head() {
  local head_sha="$1" remote_url out matched

  # SSH remote では下の http.* もプロンプト抑止も効かないため、そもそも試みない（下記の表）。
  remote_url="$(git remote get-url origin 2>/dev/null)" || return 0
  case "$remote_url" in
    http://*|https://*) ;;
    *) return 0 ;;
  esac

  out="$(GIT_TERMINAL_PROMPT=0 git \
    -c credential.helper= -c core.askPass= \
    -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 \
    ls-remote origin 'refs/pull/*/head' 2>/dev/null)" || return 0

  # 件数判定までawk側で完結させる（wcの起動を消す）。ちょうど1件のときだけ出力する。
  matched="$(printf '%s\n' "$out" \
    | awk -v sha="$head_sha" '$1 == sha { n++; r = $2 } END { if (n == 1) print r }')"
  [ -n "$matched" ] || return 0

  # basename相当はパラメータ展開で行う（sedを起動しない）
  matched="${matched#refs/pull/}"
  printf '%s\n' "${matched%/head}"
}
```

**制約と根拠**:

| 決めごと | 根拠 |
|---|---|
| **一致がちょうど1件のときだけ返す。** 0件・2件以上・失敗はすべて空を返す | `refs/pull` には閉じたPRのrefも残り（実測）、`git ls-remote` は state も base も返さないため、番号の大小では正しいPRを選べない（調査結果Q3、フェーズ2レビュー2回目の1件目） |
| **GitHubのみ。** GitLab版は作らない | `refs/merge-requests/〈n〉/head` をこの環境で実機検証できない（`references/mcp-fallback.md` §5 と同じ判断）。**副次的に、GitLabの `glab api` 経路へ新たに入る懸念（同1回目の6件目）も消える** |
| **remoteが `http://` / `https://` で始まるときだけ試みる** | **`http.*` の設定はHTTPトランスポートにしか効かない。** scp形式（`git@host:o/r.git`）・`ssh://` では下記のタイムアウトもプロンプト抑止も**丸ごと無効**になり、初回接続（known_hosts未登録）や鍵パスフレーズで**hookが無応答になる**。`repo_url_from_remote_url` がscp形式・`ssh://` を明示サポートしている以上、SSH remoteの配布先は想定内である（フェーズ3レビュー1回目の3件目）。`GIT_SSH_COMMAND='ssh -o BatchMode=yes'` を足す案もあるが、**ssh側の失敗モードを網羅できたと確認する手段がこの環境に無い**ため、試みない側へ倒す（Compareへ縮退するだけで後退しない） |
| `GIT_TERMINAL_PROMPT=0` に加え `-c credential.helper=` `-c core.askPass=` | 前者は端末プロンプトしか止めず、git bashのGit Credential ManagerのGUIダイアログは止まらない（フェーズ2レビュー2回目の2件目）。**効果はこの環境で未検証** |
| `-c http.lowSpeedLimit` / `-c http.lowSpeedTime` | 最悪の失敗は非0終了ではなく**ハング**であり、`( main ) || true` では救えない（同3件目）。`timeout` コマンドはgit bash（MSYS）での可用性が未確認のため使わない |
| 失敗時は `return 0` で**空を出力**する（非0で返さない） | 呼び出し側が `set -e` 配下でコマンド置換に入れるため。**非0が漏れるとhook全体が途中終了し、レビュー依頼メッセージが1行も出なくなる**（現行より明確な後退）。`|| true` を呼び出し側へ強いない |
| **`awk` は完全一致（`$1 == sha`）で比較する** | 部分一致にすると短縮SHAが別コミットに当たりうる |
| **`wc -l` を使わない**（件数判定を `awk` へ寄せる） | fork1回を減らすほか、`wc` の実装によっては出力の先頭に空白が入り、`[ "$count" = "1" ]` の**文字列比較が常に不一致になる**（＝常に空を返す＝機能が入らない）。同じ理由で `sed 's|/head$||'` もパラメータ展開へ置き換える（フェーズ3レビュー1回目の7件目） |

`Provider.sh` へは、他のプロバイダ関数と同じ形のディスパッチャを置く（GitLabは何もせず空を返す）。

```bash
resolve_mr_number_for_head() {
  local head_sha="$1"
  case "$(get_provider)" in
    github) github_resolve_mr_number_for_head "$head_sha" ;;
    gitlab) ;;   # 未対応（refs/merge-requests を実機検証できていない）
  esac
}
```

### 作業3: hookの配線（`compare_url` と `diff_url` の分離）

**対象**: `.claude/hooks/post-push-compact-prompt.sh`

#### 3-a. 324〜326行目: `compare_url` の分離

```bash
# 置き換え前
local repo_url diff_url
repo_url="$(get_repo_url)"
diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"

# 置き換え後
local repo_url compare_url diff_url
repo_url="$(get_repo_url)"
compare_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"
diff_url="$compare_url"
```

**巻き添えの確認**: 置き換え前の `local repo_url diff_url` は **`repo_url` の `local` 宣言を
兼ねている**。置き換え後も同じ行で宣言する（`compare_url` を足すだけ）。

#### 3-b. 332行目（`current_sha` の算出）の直後: PR URL解決と `diff_url` の再計算

**この2つのブロックは両方ともここへ置く。** 片方だけを移すと機能が無言で入らない（下記）。

```bash
current_sha="$(git rev-parse HEAD)"        # ← 既存の332行目。ここまでは変更しない

# --- ここから追加 ---
# MCP経路（CLI不在）でPR URLを解決できるなら、差分リンクをDiffviewへ寄せる（issue #205）。
# 解決できなければ compare_url のまま（＝後退しない）。
if [ -z "$mr_url" ]; then
  mr_number="$(resolve_mr_number_for_head "$current_sha")"
  if [ -n "$mr_number" ]; then
    mr_url="$(get_mr_url "$repo_url" "$mr_number")"
  fi
fi
if [ -n "$mr_url" ]; then
  diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch" "$mr_url")"
fi
# --- ここまで追加 ---
```

**なぜ両方をここへ置くのか（片方だけ移したときの壊れ方）**:

`diff_url` の再計算（後半の `if`）を 3-a の位置に残すと、`diff_url` は `mr_url` が解決される
**前**に確定する。結果、**解決に成功しても `diff_url` はCompareのままになり、issue #205 の機能が
丸ごと無言で入らない。** しかも `bash -n`・既存の単体テスト・下記の検証2・3はすべて緑になる。

**巻き添えの確認**:

- `current_sha` は332行目で算出される。**解決の呼び出しをそれより前へ置くと `set -u` 配下で
  `current_sha: unbound variable` になる。**
- `mr_number` は316行目で `local mr mr_url="" mr_number=""` として宣言済み。**再宣言しない。**
- **`diff_url` を2回コマンド置換で呼ばない。** `mr_url` が空のときに2回目の戻り値は必ず1回目と
  同じで、fork1回（git bashで約95ms）が無駄になる。上のように `if` で囲む。

#### 3-c. 358行目: アンカーの土台を `compare_url` へ戻す

```bash
# 置き換え前（実物。file_links_text の宣言を兼ねている）
local anchor_compare_url="$diff_url" file_links_text=""
# 置き換え後
local anchor_compare_url="$compare_url" file_links_text=""
```

**巻き添えの確認**: **この行は `file_links_text` の `local` 宣言と空文字初期化も兼ねている。**
`anchor_compare_url` の部分だけを書き換え、後半をそのまま残すこと。落とすと371行目の
`file_links_text="$(build_file_links_text ...)"` がグローバルへの代入になり、`main` の外へ漏れる
（現在は `( main )` がサブシェルのため即座の実害は無いが、後でその代入が条件分岐の中へ入った
瞬間に `set -u` 配下で `file_links_text: unbound variable` になる）。

これが**後退を防ぐ要**である。GitHubの差分アンカー `#diff-〈sha256〉` はCompareページ上でしか
実機確認していないため、土台を `/files` へ移すと「壊れるかもしれないリンク」になる。

### 作業4: テストの追加

**対象**: `.claude/scripts/test/test_vcs_provider.sh`

| 追加するもの | 何を守るか |
|---|---|
| `github_get_mr_diff_url` / `gitlab_get_mr_diff_url` の**4引数版**アサーション | Diffview URLの形（`/files`・`/diffs`） |
| 同関数の**3引数版**アサーション（既存の維持） | 4引数化で既存の呼び出しが壊れていないこと |
| **ディスパッチャ経由の経路テスト** | `Provider.sh` の `get_mr_diff_url` が第4引数を下位へ渡すこと |
| `github_resolve_mr_number_for_head` の**戻り値の分岐**（0件／1件／2件以上／**`ls-remote` の失敗**／**SSH remote**） | 「1件のときだけ返す」「失敗しても空＋終了コード0」「SSHでは試みない」 |
| **冒頭コメント（6-7行目）の書き換え** | 「Provider.sh経由のディスパッチは対象外」が**偽になる**ため |
| `github_get_diff_anchor_base_url` の既存7アサーション（**変更しない**） | アンカーの挙動が変わっていないこと |

**冒頭コメントの書き換え**（作業4の成果物に含める）: 現在の6-7行目は
「Provider.sh経由のディスパッチ（`get_mr_diff_url`等）は…対象外」と、**今回テストを足す当の関数を
名指しで対象外と宣言している**。`get_provider` をサブシェルでスタブすれば外部コマンドなしで
ディスパッチを覆えることを踏まえ、当該2行を書き換える（正が2つあると片方だけ古くなる）。

**ディスパッチャ経由のテストの書き方**（`.claude/rules/shell-script-style.md`「テスト」の2つの罠を踏まえる）:

```bash
# 差し替えはサブシェルへ閉じ込め、アサーションは括弧の外で行う
assert_eq "ディスパッチャが第4引数を渡す(github)" \
  "https://github.com/o/r/pull/206/files" \
  "$( get_provider() { printf 'github\n'; }; \
      get_mr_diff_url 'https://github.com/o/r' 'main' 'feat' 'https://github.com/o/r/pull/206' )"
# 実定義が消えていないことも表明する
assert_eq "get_providerの実定義が残っている" "get_provider" \
  "$(declare -F get_provider >/dev/null && echo get_provider)"
```

- サブシェルの中で `assert_eq` を呼ばない（`failures` が加算されず、**失敗しても緑になる**）。
- `unset -f` を使わない（bashの関数定義はスタックしないため、**実定義そのものが消える**）。

**挿入位置の制約（実装時に必ず確認する）**: `test_vcs_provider.sh` は **220行目付近で
`get_provider` をファイル全域に効く形で上書きしており**、そのコメント自身が
「この上書きは以降のテスト全体に効く。**`get_provider` に依存するテストをこれより後ろへ
追加しないこと**」と警告している。今回追加するディスパッチャ経路テストは、まさに
`get_provider` に依存する。したがって次のいずれかを採る。

| 案 | 内容 | 判断 |
|---|---|---|
| (i) | 上書きより**前**（220行目より上）へ挿入する | **採用**。既存の警告に従える |
| (ii) | 上書きより後ろへ置き、サブシェル内のスタブで上書きを打ち消す | 採らない。動きはするが、警告を無視した前例を作る |

**この制約は上記の敵対的レビューでは検出されていない**（実装ファイルを読んで自分で見つけた）。
挿入位置を間違えると、テストは通るのに「何を固定しているのか」が別物になる。

**失敗経路のテスト**（最も起きやすい経路であり、漏れるとhookごと止まる）:

```bash
# git スタブが非0で終わっても、出力は空・終了コードは0であること
resolve_fail_out="$( git() { return 128; }; github_resolve_mr_number_for_head 'deadbeef' )"
assert_eq "ls-remote失敗時は空を返す" "" "$resolve_fail_out"
if ( git() { return 128; }; github_resolve_mr_number_for_head 'deadbeef' >/dev/null ); then
  resolve_fail_status=0
else
  resolve_fail_status=1
fi
assert_eq "ls-remote失敗時も終了コードは0" "0" "$resolve_fail_status"
```

終了コードの検査に `"$(func; echo $?)"` の形は使わない（`inherit_errexit` の設定とbashの版で
挙動が変わる。同ルール「テスト」）。

## この計画で決めないこと（スコープ外）

| 項目 | どこで決めるか |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` の「提供関数」表・未決定事項の差し替え | **flow-id 4-1**（個別反映計画） |
| DDR `i0205-01` の作成 | **flow-id 4-1** |
| `references/mcp-fallback.md` への追記（hook縮退表・MCPツールの本文改変） | **flow-id 4-1** |
| `http.lowSpeedTime` の秒数の妥当性の実測 | **実測できない**。specの未決定事項へ引き継ぐ（flow-id 4-1） |
| SSH remoteでのPR URL解決（`GIT_SSH_COMMAND` 等） | **別issue**。今回は「試みない」ことで安全側へ倒す |
| GitLabの `refs/merge-requests` 対応 | **別issue**（実機検証できる環境が用意できた時点） |

## スコープの拡大: `build_links_text` の出力が2箇所変わる

**issueの受け入れ条件に無い変更**であり、人間の承認を求めている項目である
（調査結果「解決したPR URLの格納先」節からの転記）。

| 出力 | 現在（MCP経路） | 変更後 |
|---|---|---|
| `- MR:` 行 | `(gh/glab CLI不在のため未取得。mcp__github__list_pull_requests で … 取得すること)` という**指示文** | **PR URLの実リンク** |
| `- コメント一覧(MR画面):` 行 | **出ない**（`mr_url` が空のため） | **2回目以降のpushで新たに出る** |

`mr_url` を採った理由は、同じ値を2箇所で別々に持つと食い違いうるためである（別変数にすると
「MR行は『未取得』と言っているのに差分リンクはPRを指している」状態になる）。

## 検証

実際に実行するコマンドを示す。

```bash
# 1. 構文チェック（変更した4ファイル）
for f in .claude/scripts/src/vcs/Github.sh .claude/scripts/src/vcs/Gitlab.sh \
         .claude/scripts/src/vcs/Provider.sh .claude/hooks/post-push-compact-prompt.sh; do
  bash -n "$f" || echo "NG: $f"
done

# 2. 単体テスト全件（baselineは failures=0 / 21ファイル）
for t in .claude/scripts/test/test_*.sh; do
  out="$(bash "$t" 2>&1 | tail -1)"
  case "$out" in *"failures=0"*) : ;; *) echo "NG: $t -> $out" ;; esac
done

# 3. 追加したテストが「空振りでない」ことの確認
#    作業ツリーは一切書き換えない。一時ツリーへコピーして壊す
#    （test_vcs_provider.sh の1344-1352行と同じ形）
#    注: test_vcs_provider.sh は source 元を `$repo_root` で決め打ちしており、環境変数で
#    差し替えられない。そのため「テストを一時ツリーに対して流す」ことはできず、
#    ディスパッチャの振る舞いを直接確かめる形にする。
broken_dir="$(mktemp -d)"
cp .claude/scripts/src/vcs/Provider.sh .claude/scripts/src/vcs/Github.sh \
   .claude/scripts/src/vcs/Gitlab.sh "$broken_dir/"
before=$(grep -c -e '"$mr_url"' "$broken_dir/Provider.sh")
sed -i 's|github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" "$mr_url"|github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch"|' \
  "$broken_dir/Provider.sh"
after=$(grep -c -e '"$mr_url"' "$broken_dir/Provider.sh")
# 改変が1件入ったことを先に表明する（sedは一致しなくても終了コード0のため）
[ "$((before - after))" -eq 1 ] || echo "NG: sedが当たっていない（before=$before after=$after）"

# 壊した側のディスパッチャが /files を返さなくなること（＝追加するアサーションが落ちること）
broken_out="$(
  source "$broken_dir/Github.sh"; source "$broken_dir/Gitlab.sh"; source "$broken_dir/Provider.sh"
  get_provider() { printf 'github\n'; }
  get_mr_diff_url 'https://github.com/o/r' 'main' 'feat' 'https://github.com/o/r/pull/206'
)"
# 期待: Compare URL（/files ではない）。ここが /files のままなら、この検証自体が空振りである
printf 'broken=%s\n' "$broken_out"
case "$broken_out" in
  */files) echo "NG: 壊したのに /files が返っている（検証が空振り）" ;;
  *) echo "OK: 壊すと /files が返らなくなる＝追加するアサーションは空振りでない" ;;
esac
rm -rf "$broken_dir"

# 4. hookをダミーペイロードで直接実行し、出力を機械判定する
#    （状態ファイルを汚さないよう、実行前に退避して実行後に戻す）
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push"}}' \
  | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/post-push-compact-prompt.sh \
  | jq -r '.hookSpecificOutput.additionalContext')"
# 4-a. defaultブランチとの差分が /files で終わること（1件）
printf '%s\n' "$out" | grep -c -e '^- defaultブランチとの差分: .*/files$'
# 4-b. 差分アンカー付きリンクが「すべて」Compare上にあること（後退していないこと）
#      2つの件数が一致すること（一致しなければ、土台が /files へ移っている）
printf '%s\n' "$out" | grep -c -e '#diff-'
printf '%s\n' "$out" | grep -e '#diff-' | grep -c -e '/compare/'
# 4-c. MR行が実リンクになったこと（スコープ拡大分。1件）
printf '%s\n' "$out" | grep -c -e '^- MR: https://'
```

**3と4-bが最も重要な検証である。** 3は「純粋関数のテストは通るのにディスパッチャの受け渡しが
漏れている」状態（issue #127 と同型）を、4-bは「重点ファイルリンクが1本でも `/files` へ移って
しまった」状態を検出する。**4-bを目視で代替しない**（リンクは最大10件あり、1本の見落としが後退になる）。

**この環境で検証できないこと**: `gh`/`glab` CLIが存在しないため、**CLI経路（`get_vcs_access_mode`
が `cli` を返す経路）の挙動は検証4では一切確かめられない。** CLI経路では `mr_url` が最初から
非空なので、追加した解決ブロックは素通りし `diff_url` だけがDiffviewへ変わる——という読みは
**コードを読んだ上での判断であり、実機での確認ではない。**

## 完了条件

1. 上記の作業1〜4がすべて実装され、検証1・2が通ること。
2. **検証3で、`sed` が1件当たったこと（`before - after == 1`）を確認したうえで、テストが実際に
   落ちること**。落ちなければテストが空振りか、`sed` が当たっていないかのどちらかであり、
   **どちらなのかを区別してから直す**。
3. 検証4-a が **1** であること（`- defaultブランチとの差分:` が `/pull/206/files` で終わる）。
4. **検証4-b の2つの件数が一致すること**（差分アンカー付きリンクがすべてCompare上にある
   ＝アンカーの土台が変わっていない＝後退していない）。
5. 検証4-c が **1** であること（MR行が実リンクへ変わった。スコープ拡大分の確認）。
6. 2回目以降のpushで `- コメント一覧(MR画面):` 行が出ること（同上）。
7. **GitLab経路が変わっていないこと**を単体テストで確認していること
   （`gitlab_get_diff_anchor_base_url` の7アサーションが変更なしで通る）。

## 停止条件（フェーズ4へ進んではいけない場合）

| 条件 | 対処 |
|---|---|
| **検証3で、`sed` は当たったのにテストが落ちない** | テストが空振りである。書き直す。落ちるようになるまでフェーズ4へ進まない |
| **検証3で、`sed` が当たっていない**（`before - after != 1`） | テストではなく**検証手順**の問題である。テストを触らず、`sed` のパターンを実装後のコードへ合わせる |
| **検証4-a が 0 になる** | **まず配線バグと縮退を切り分ける。** `resolve_mr_number_for_head "$(git rev-parse HEAD)"` を単体で実行し、(i) 空を返すなら**縮退が正しく効いている**ので失敗ではない（「この環境では解決できなかった」と結果へ明記する）、(ii) **値が返るのに hook 出力がCompareのままなら配線バグ**（作業3-b の2ブロックの配置を確認する）。**この切り分けをせずに「縮退が効いた」と判定しない** |
| **検証4-b の2つの件数が一致しない** | アンカーの土台が `/files` へ移っている。**後退である。** 作業3-c を確認する |
| **既存の単体テストが1件でも落ちる** | 後退である。フェーズ4へ進まない |
| **hookがハング・遅延する（体感で分かる程度）** | 解決自体を諦める（Compareのままにする）。**pushの後処理が止まることは、Diffviewリンクが得られる価値より重い** |
