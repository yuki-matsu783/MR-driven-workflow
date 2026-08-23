---
title: 【設計反映】【AIアセット反映】stateのwip移設をドキュメントへ反映する
type: plan
description: .claude/state を wip/state へ移した結果を rules・spec・DDRへ反映し、作業中に判明した2つの罠をAIアセットへ書き足す計画
tags: [plan, workflow, documentation]
keywords: [設計反映, AIアセット反映, DDR, directory-structure, issue-mr-workflow, git-workflow, shell-script-style, wip, state]
---

# 【設計反映】【AIアセット反映】stateのwip移設をドキュメントへ反映する

- issue: #184 / PR: #190
- 全体作業計画: `plans/wispy-drifting-lantern.md`
- フェーズ4〈反映〉 flow-id 4-1

## 前提（合意状況）

- 依拠する作業結果: `reports/20260823_wispy-drifting-lantern_stateのwip-stateへの移設.md`
  （flow-id 3-6。人間のレビュー往復はこのセッションでは実施できていない）。
- `【設計反映】`と`【AIアセット反映】`を併記するのは、**どちらも同じ1回の作業結果から出ており、
  合意を分けて取る意味が無い**ため（`references/planning.md`「種別を複数併記する場合」）。

## この計画で何をするか

1. **設計反映**: `.claude/state/` を名指ししている「現在の状態を説明する記述」を `wip/state/`
   へ更新し、移設の判断をDDRとして残す。
2. **AIアセット反映**: 作業中に踏んだ2つの罠を、既存ルールへ**追記**する。

## AIアセット反映の対象の洗い出し（手順1〜3の結果）

### 手順1: 起点の列挙（2件）

いずれも `worklog/…push2.md` の「ダメだったこと」と、`reports/…md` の「想定と異なった点」から。

| # | 既存のアセットで対応できなかったこと |
|---|---|
| 1 | `.gitignore` のパターンを移設すると、**旧パスに残っている既存ファイルが追跡対象として `git status` に現れる**。計画時点で気づけず、差し替えた直後に `?? .claude/state/` が出て初めて分かった |
| 2 | テストの**フィクスチャを別パスへ差し替えると、そのテストが検証したい経路から外れて空振りになる**ことがある。`test_sync_gemini_assets.sh` のT8を `wip/state/` へ替えかけたが、`sync-gemini-assets.sh` の列挙は `-- .claude` に限られるため、`.gitignore` の効果と無関係に常に成功するテストへ変わるところだった |

`worklog/` は作成済み・記入済みであり、「記録が無いから0件」ではない。
MRのレビューコメントは、このセッションでは往復が発生していないため入力に含まれない。

### 手順2: 4類型への分類

| # | 類型 | 反映の向き | 判定の根拠 |
|---|---|---|---|
| 1 | **(c)** アセットはあったが、その罠が書かれていなかった | `.claude/rules/git-workflow.md`「コミット運用」へ**追記** | `.gitignore` と副産物の扱いを定めた記述はある（「新種の副産物を見つけたら `.gitignore` と `commit` スキルの除外リストの両方へ追加する」）が、**既存パターンを移設したときの旧パスの扱い**は書かれていない |
| 2 | **(c)** 同上 | `.claude/rules/shell-script-style.md`「テスト」へ**追記** | 「異常が無ければ何も出ない形の検出は、パターンが実データに合っていないと常に成功する」（923行目）という**同根の罠**はあるが、扱っているのは静的検出のパターンであり、**テストのフィクスチャを差し替えたときに検証経路から外れる**という形は書かれていない |

### 手順3: 痕跡の確認

**2件とも (c) なので再現性の証拠は要求しない**（手順3の表のとおり、再現性を要求するのは (a) のみ）。
一方、**(c) の判定には「その罠を扱った記述が本当に無いこと」の確認が要る**ため、段階2を実施した。

| # | `search-frontmatter.sh` | `grep -rn … .claude/docs .claude/rules` | 判定 |
|---|---|---|---|
| 1 | `--text 'gitignore' --format count` → `matched=9 total=159` | `残骸` → DDR `i0039-01` の1件のみ（本件と無関係の文脈）／`旧パス` → いずれも `git status --porcelain` の改名エントリと `.gemini/` の生成物の話 | 該当記述なし → **(c) で確定** |
| 2 | （`grep` で先に該当が出たため段階2の1段で確定） | `空振り` → hookの前置フィルタ・配布の空振りエントリ／`常に成功` → `shell-script-style.md:923` の静的検出の話 | **近い記述はあるが同じ罠ではない** → **(c) で確定**（同じ節へ隣接させて書く） |

**段階3（直近10件のマージ済みPR＋DDR一覧）へは進まない。** 段階2で (c) が確定しており、
段階3は「(a) として反映してよいか」を決めるための段だからである。

### 手順4: 反映先の形態

| # | 反映先 | いつ効くか | 選んだ理由 |
|---|---|---|---|
| 1 | `.claude/rules/git-workflow.md` | セッション開始時（常時読込） | `.gitignore` と `git status` の扱いは、コミットのたびに効く必要がある。既に「コミット運用」節が同じ関心を扱っている |
| 2 | `.claude/rules/shell-script-style.md` | 同上 | 既存の「テスト」節へ隣接させる。テストを書く／直すときに読まれる位置 |

いずれも**既存節への追記**であり、常時読込のアセットを新規に増やさない。

## 変更対象

### 設計反映

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/rules/directory-structure.md` | 変更 | ツリー直後の注記（`reports/`・`usage/`・`.claude/state/` の並び）と、`.claude/state/` の説明段落を `wip/state/` へ。移行用の除外行にも触れる |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「/compact実施の呼びかけ」節（**現在の仕様**）を新パスへ。**changelog（2299〜2300行目）は触らず、末尾へ issue #184 の新規エントリを追記** |
| `.claude/docs/spec/adversarial-review.md` | 変更 | 状態ファイルのパス（100〜101行目） |
| `.claude/docs/spec/sync-gemini-assets.md` | 変更 | 除外対象の説明（67行目） |
| `.claude/docs/ddr/i0184-01-….md` | 新規 | 移設先を `wip/state/` にした判断・却下案・移行用の除外行を残した判断 |
| `.claude/docs/README.md` | 変更 | `bash .claude/scripts/src/generate-ddr-list.sh` の生成結果 |

### AIアセット反映

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/rules/git-workflow.md` | 変更 | 「コミット運用」節へ、`.gitignore` のパターン移設時に旧パスの扱いを判断する項を追記 |
| `.claude/rules/shell-script-style.md` | 変更 | 「テスト」節へ、フィクスチャ差し替えでテストが空振りになる罠を追記 |

### 実装反映

**該当なし。** フェーズ3のレビュー往復（3-6〜3-9）で持ち越した不具合は無い
（作業中に判明した「旧パスの除外行」はフェーズ3の中で解消済み）。

## やらないこと（スコープ外）

- **既存DDR `i0013-01` `i0039-01` の本文の書き換え**。旧パス表記のまま残す。
- **`.claude/docs/spec/issue-mr-workflow.md` の過去changelogの書き換え**（2299〜2300行目）。
  移設の事実は**新規エントリ**として追記する。
- **`.claude/docs/usecase/` の更新**。9本を確認したが、`.claude/state/` に触れているものは
  無かった（`gitignore` の唯一の言及は `index.jsonl` の話）。**確認は実施し、結果は0件**。
- **`.claude/VERSION` の更新**。判断は人間に委ねる（`.claude/docs/spec/distribution-assets.md`）。

## 検証

```bash
bash .claude/scripts/src/generate-ddr-list.sh
bash .claude/scripts/src/check-doc-references.sh
bash .claude/scripts/src/extract-frontmatter.sh .

# 過去changelog・DDR本文を書き換えていないこと（削除行がゼロであること）
git diff 4be448a -- .claude/docs/ddr/ | grep -c '^-[^-]' || true
```

合格条件:

1. `generate-ddr-list.sh` の実行後、`.claude/docs/README.md` に `i0184-01` の行がある。
2. `check-doc-references.sh` が参照切れ0件で終わる。
3. **既存DDRの本文に削除行が1行も無い**（新規DDRの追加のみ）。
4. `.claude/docs/spec/issue-mr-workflow.md` の2299〜2300行目（過去changelog）が無変更である。
