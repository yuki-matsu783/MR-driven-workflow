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
  local head_sha="$1" out matched count
  out="$(GIT_TERMINAL_PROMPT=0 git \
    -c credential.helper= -c core.askPass= \
    -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 \
    ls-remote origin 'refs/pull/*/head' 2>/dev/null)" || return 0
  matched="$(printf '%s\n' "$out" | awk -v sha="$head_sha" '$1 == sha { print $2 }')"
  [ -n "$matched" ] || return 0
  count="$(printf '%s\n' "$matched" | wc -l)"
  [ "$count" = "1" ] || return 0
  printf '%s\n' "${matched#refs/pull/}" | sed 's|/head$||'
}
```

**制約と根拠**:

| 決めごと | 根拠 |
|---|---|
| **一致がちょうど1件のときだけ返す。** 0件・2件以上・失敗はすべて空を返す | `refs/pull` には閉じたPRのrefも残り（実測）、`git ls-remote` は state も base も返さないため、番号の大小では正しいPRを選べない（調査結果Q3、敵対的レビュー2回目の1件目） |
| **GitHubのみ。** GitLab版は作らない | `refs/merge-requests/〈n〉/head` をこの環境で実機検証できない（`references/mcp-fallback.md` §5 と同じ判断）。**副次的に、GitLabの `glab api` 経路へ新たに入る懸念（敵対的レビュー1回目の6件目）も消える** |
| `GIT_TERMINAL_PROMPT=0` に加え `-c credential.helper=` `-c core.askPass=` | 前者は端末プロンプトしか止めず、git bashのGit Credential ManagerのGUIダイアログは止まらない（同2件目）。**効果はこの環境で未検証** |
| `-c http.lowSpeedLimit` / `-c http.lowSpeedTime` | 最悪の失敗は非0終了ではなく**ハング**であり、`( main ) || true` では救えない（同3件目）。`timeout` コマンドはgit bash（MSYS）での可用性が未確認のため使わない |
| 失敗時は `return 0` で**空を出力**する（非0で返さない） | 呼び出し側が `set -e` 配下でコマンド置換に入れるため。`|| true` を呼び出し側へ強いない |
| **`awk` は完全一致（`$1 == sha`）で比較する** | 部分一致にすると短縮SHAが別コミットに当たりうる |

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

```bash
# 置き換え前（326行目付近）
local repo_url diff_url
repo_url="$(get_repo_url)"
diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"

# 置き換え後
local repo_url compare_url diff_url
repo_url="$(get_repo_url)"
compare_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"
diff_url="$compare_url"

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
```

**巻き添えの確認（置き換え対象の行が兼ねていた役割）**:

- 置き換え前の `local repo_url diff_url` は **`repo_url` の `local` 宣言を兼ねている**。
  置き換え後も同じ行で宣言する（`compare_url` を足すだけ）。
- **`current_sha` は328〜332行目で算出されており、上の挿入位置より後ろにある。**
  そのため解決の呼び出しは `current_sha` の算出**より後ろ**へ置く必要がある。
  上のスケッチの位置のままでは `set -u` 配下で `current_sha: unbound variable` になる。
  **実装時は `current_sha="$(git rev-parse HEAD)"` の直後へ移す。**
- `mr_number` は316行目で `local mr mr_url="" mr_number=""` として宣言済み。再宣言しない。
- **`diff_url` を2回コマンド置換で呼ばない。** `mr_url` が空のときに2回目の戻り値は必ず1回目と
  同じで、fork1回（git bashで約95ms）が無駄になる（敵対的レビュー2回目の報告のみ3件目）。
  上のように `if` で囲む。

**アンカーの土台は `compare_url` を渡し続ける**（352行目以降）。

```bash
# 置き換え前
local anchor_compare_url="$diff_url"
# 置き換え後
local anchor_compare_url="$compare_url"
```

これが**後退を防ぐ要**である。GitHubの差分アンカー `#diff-〈sha256〉` はCompareページ上でしか
実機確認していないため、土台を `/files` へ移すと「壊れるかもしれないリンク」になる。

### 作業4: テストの追加

**対象**: `.claude/scripts/test/test_vcs_provider.sh`

| 追加するもの | 何を守るか |
|---|---|
| `github_get_mr_diff_url` / `gitlab_get_mr_diff_url` の**4引数版**アサーション | Diffview URLの形（`/files`・`/diffs`） |
| 同関数の**3引数版**アサーション（既存の維持） | 4引数化で既存の呼び出しが壊れていないこと |
| **ディスパッチャ経由の経路テスト** | `Provider.sh` の `get_mr_diff_url` が第4引数を下位へ渡すこと |
| `github_resolve_mr_number_for_head` の**戻り値の分岐**（0件／1件／2件以上） | 「1件のときだけ返す」という最重要の制約 |
| `github_get_diff_anchor_base_url` の既存7アサーション（**変更しない**） | アンカーの挙動が変わっていないこと |

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

`github_resolve_mr_number_for_head` のテストでは `git` をシェル関数で差し替える（同じくサブシェル内）。

## この計画で決めないこと（スコープ外）

| 項目 | どこで決めるか |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` の「提供関数」表・未決定事項の差し替え | **flow-id 4-1**（個別反映計画） |
| DDR `i0205-01` の作成 | **flow-id 4-1** |
| `references/mcp-fallback.md` への追記（hook縮退表・MCPツールの本文改変） | **flow-id 4-1** |
| `http.lowSpeedTime` の秒数の妥当性の実測 | **実測できない**。specの未決定事項へ引き継ぐ（flow-id 4-1） |
| GitLabの `refs/merge-requests` 対応 | **別issue**（実機検証できる環境が用意できた時点） |

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

# 3. 追加したテストが「空振りでない」ことの確認（変更前から通る形になっていないか）
#    Provider.sh の第4引数の受け渡しを意図的に落として、経路テストだけが落ちることを見る
cp .claude/scripts/src/vcs/Provider.sh /tmp/Provider.sh.bak
sed -i 's|github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" "$mr_url"|github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch"|' \
  .claude/scripts/src/vcs/Provider.sh
bash .claude/scripts/test/test_vcs_provider.sh | tail -1   # failures が1以上になること
cp /tmp/Provider.sh.bak .claude/scripts/src/vcs/Provider.sh

# 4. hookを実際に走らせ、defaultブランチとの差分リンクが /files になることを見る
#    （このセッションのpushで自動的に走るため、出力を目視で確認する）
```

**3が最も重要な検証である。** 純粋関数のテストは通るのにディスパッチャの受け渡しが漏れている、
という状態を検出できなければ、このテストは追加する意味が無い（issue #127 と同型の失敗）。

## 完了条件

1. 上記の作業1〜4がすべて実装され、検証1・2が通ること。
2. **検証3で、意図的に壊したときに実際にテストが落ちること**を確認していること
   （落ちなければ、そのテストは空振りである）。
3. 検証4で、この環境のhook出力の「defaultブランチとの差分」が
   `https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files` になること。
4. **同じhook出力の「重点レビュー対象の候補ファイル」の差分リンクが、従来どおりCompareのまま**
   であること（アンカーの土台が変わっていない＝後退していないことの確認）。
5. **GitLab経路が変わっていないこと**を単体テストで確認していること
   （`gitlab_get_diff_anchor_base_url` の7アサーションが変更なしで通る）。

## 停止条件（フェーズ4へ進んではいけない場合）

| 条件 | 対処 |
|---|---|
| **検証3で、意図的に壊してもテストが落ちない** | テストを書き直す。落ちるようになるまでフェーズ4へ進まない |
| **検証4でhook出力が `/files` にならない** | 原因を切り分ける。`resolve_mr_number_for_head` が空を返しているだけなら**縮退が正しく効いている**ので失敗ではないが、その場合は「この環境では解決できなかった」と結果へ明記する |
| **既存の単体テストが1件でも落ちる** | 後退である。フェーズ4へ進まない |
| **hookがハング・遅延する（体感で分かる程度）** | `http.lowSpeedTime` の値を見直すか、解決自体を諦める（Compareのままにする）。**pushの後処理が止まることは、Diffviewリンクが得られる価値より重い** |
