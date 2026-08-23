---
title: 【AIアセット反映】ディレクトリ構成とVERSIONの更新
type: plan
description: 作業の副産物として気づいたAIアセットの不備（ツリー・Repository Mapの欠落）を直し、.claude/VERSION の増分をユーザーへ提案する
tags: [plan, AIアセット反映, directory-structure, version]
keywords: [directory-structure, index.md, Repository Map, VERSION, SemVer, agent-common, check-dist-coverage, asset-manifest]
---

# 【AIアセット反映】ディレクトリ構成とVERSIONの更新

flow-id 4-6（AIアセット反映）。作業の**副産物**として気づいたルール・スキルの不備を
`.claude/rules/` `.claude/skills/` `AGENTS.md` `CLAUDE.md` へ反映する。

**この計画は3つの反映のうち最後に実施する。** `.claude/VERSION` の増分は、
`【実装反映】`・`【設計反映】`で配布対象アセットがどこまで変わったかが確定してからでないと
提案できないため。

## この計画の範囲

| 対象 | やること |
|---|---|
| `.claude/rules/directory-structure.md` | ツリーへ新規ファイル3件を追記 |
| `index.md`（Repository Map） | 同上（`agent-common.md` が欠落） |
| `.claude/VERSION` | 増分を**提案**する（決めるのは人間） |

**範囲外**: spec / DDR（`【設計反映】`）、実装・テスト（`【実装反映】`）、
`ai-asset:` prefix の運用規約（**フェーズ3で `commit` スキルへ反映済み**。下記「既に済んでいるもの」）。

## 1. ツリー・Repository Map の欠落を埋める

実測（`grep -c`）で確認した欠落は次のとおり。

| ファイル | `directory-structure.md` | `index.md` |
|---|---|---|
| `.claude/dist-layers.json` | **あり** | **あり** |
| `.claude/scripts/src/check-dist-coverage.sh` | **無い** | あり |
| `.claude/rules/agent-common.md` | **無い** | **無い** |
| `.claude/.asset-manifest.json`（配布先に置かれる） | **無い** | — |

- **`agent-common.md` は本issueが新設した core のルールファイル**で、`AGENTS.md` `CLAUDE.md`
  `GEMINI.md` の3つがこれを `@import` している。ツリーにも Repository Map にも無いのは、
  「AIが読むもの」の入口が案内から抜けている状態である。
- **`.asset-manifest.json` は配布先にだけ生成される**ため、このリポジトリのツリーには実体が無い。
  `reports/` `usage/` `.claude/state/` と同じく「動的に作られるもの」として、
  ツリー本体ではなく**その直後の説明文へ**書く（ツリーに載せると本家に存在すると誤読される）。

## 2. `.claude/VERSION` の増分を提案する

現在値は **`0.2.0`**（main のマージで `0.1.2` → `0.2.0` になった。main 側の更新であり、
このブランチは据え置いていた）。

`.claude/docs/spec/distribution-assets.md`「`.claude/VERSION`」節の規定に従う。

- **更新のタイミング**: flow-id 4-6（AIアセット反映）＝この計画。
- **増分の決め方**: AIエージェントが**提案**し、**人間が決める**（AIが独断で上げない）。
- **据え置きもありうる**。据え置く場合は、その事実を `【設計反映】` の changelog へ残す。

**提案の内容**（実施時にこの形で `AskUserQuestion` へ出す）:

| 候補 | 根拠 |
|---|---|
| **`1.0.0`（MAJOR）** | 配布の仕組みそのものが別物になった。`.skill` パッケージ手順が消え、配布先には `.claude/.asset-manifest.json` という新しいファイルが増える。旧方式で配られた `AGENTS.md` は**手作業での移行が要る**（`requiredLine` が一覧で知らせるだけで、自動では直らない）ため、規定の `MAJOR`「配布先に手作業を要求する非互換変更」に当たる |
| `0.3.0`（MINOR） | 「資産の追加・フローの拡張」と読む場合。ただし手作業の要求を説明できない |

**AIの推奨は `1.0.0`** とするが、`0.x` を保つ方針かどうかは配布方針の判断なので人間が決める。

- **`AskUserQuestion` は `【AIアセット反映】` の実施時（flow-id 4-6）に1回だけ行う。**
  この計画のレビュー（4-3〜4-4）で先に決まった場合は、それをもって確定とし重ねて聞かない。

## 既に済んでいるもの（この計画では扱わない）

フェーズ4の候補として挙げていたが、**フェーズ3で反映済み**であることを実ファイルで確認した。
再度触らない。

| 項目 | どこに入ったか |
|---|---|
| `ai-asset:` prefix の運用規約 | `.claude/skills/commit/SKILL.md` 68行目（`.claude/scripts/` を対象外とする線引きを含む） |
| `apply-mr-workflow-to-project/assets/` の位置づけ | `.claude/rules/directory-structure.md` 142〜144行目（`sync-assets.sh` 前提の記述を現状へ書き換え済み） |
| 古い形式のまま残った `seed` の扱い | `.claude/skills/apply-mr-workflow-to-project/SKILL.md`（`requiredLine` の節） |

## 検証（この計画の完了判定に実際に流すコマンド）

```bash
# 1. 欠落が埋まったこと（それぞれ 1 以上になる）
for f in check-dist-coverage.sh agent-common.md asset-manifest; do
  printf '%-24s ds=%s idx=%s\n' "$f" \
    "$(grep -c -- "$f" .claude/rules/directory-structure.md)" \
    "$(grep -c -- "$f" index.md)"
done

# 2. ツリーの体裁が壊れていないこと（罫線の対応）
sed -n '/^```$/,/^```$/p' .claude/rules/directory-structure.md | head -60

# 3. frontmatterインデックスの再生成（ファイル自体は増えないが description が変わる）
bash .claude/scripts/src/extract-frontmatter.sh .

# 4. 網羅性チェック（ファイルは増えないので分母は変わらない）
bash .claude/scripts/src/check-dist-coverage.sh

# 5. 単体テスト
for t in .claude/scripts/test/test_*.sh; do bash "$t" | tail -1; done
```

**検証2は目視である。** ツリーは罫線（`├──` `│` `└──`）で構造を表しているので、行を差し込むと
親子関係がずれる。差し込んだ位置の**前後3行**を必ず読む
（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むときは…」と同じ理由）。

## この計画の中で互いの前提を崩していないか（自己点検）

- **`.claude/VERSION` を上げると、`core` として配布先へ無条件に上書きされる。** これは仕様どおり
  （`distribution-assets.md`「`.bak` を作らず常に上書き」）だが、**この変更自体がテストを壊さないか**
  を検証5で確認する。`test_install_to_project.sh` は VERSION の値を表明していないはずだが、
  実際に流して確かめる。
- **`index.md` と `directory-structure.md` は役割が違う。** `index.md`（Repository Map）が
  ディレクトリの**役割説明**の正で、`directory-structure.md` は**ツリー構造・配置ルール**の正
  （`directory-structure.md` 冒頭に明記）。同じ説明文を両方へ書かないこと。
- **VERSIONの増分は `【設計反映】` の changelog と対になり、しかも順序が噛み合わない。**
  増分を決めるには3つの反映がどこまで配布対象を変えたかが要る（＝この計画が最後）が、
  結論を書く先は `distribution-assets.md` の issue #26 エントリ（＝`【設計反映】` の成果物）
  である。**この1行だけは `【設計反映】` へ後から書き戻す**と決めておく（順序を入れ替えて
  解消しようとしない。入れ替えると今度は増分の根拠が揃わない）。書き戻しは
  `【AIアセット反映】` のコミットに含める。
