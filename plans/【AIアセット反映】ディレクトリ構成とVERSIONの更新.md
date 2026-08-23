---
title: 【AIアセット反映】ディレクトリ構成とVERSIONの更新
type: plan
description: 作業の副産物として気づいたAIアセットの不備（ツリー・Repository Mapの欠落）を直す。.claude/VERSION は 0.2.0 のまま据え置く
tags: [plan, AIアセット反映, directory-structure, version]
keywords: [directory-structure, index.md, Repository Map, VERSION, 据え置き, agent-common, check-dist-coverage, asset-manifest, changelog]
---

# 【AIアセット反映】ディレクトリ構成とVERSIONの更新

flow-id 4-6（AIアセット反映）。作業の**副産物**として気づいたルール・スキルの不備を
`.claude/rules/` `.claude/skills/` `AGENTS.md` `CLAUDE.md` へ反映する。

**この計画は3つの反映のうち最後に実施する。** 当初の理由は「`.claude/VERSION` の増分は
他2件の結果が出そろわないと提案できないため」だったが、**据え置きが flow-id 4-4 で確定した**
ため、その理由は消えた。それでも順序は変えない——ツリー・Repository Map の更新は、
`【設計反映】` が新設する spec ファイルを**案内へ載せる**必要があるためである
（先に実施すると、新しい spec が載っていないツリーを作ることになる）。

## この計画の範囲

| 対象 | やること |
|---|---|
| `.claude/rules/directory-structure.md` | ツリーへ新規ファイル3件を追記 |
| `index.md`（Repository Map） | 同上（`agent-common.md` が欠落） |
| `.claude/VERSION` | **変更しない**（`0.2.0` のまま据え置きが flow-id 4-4 で確定）。据え置いた事実の記録は `【設計反映】` 側 |

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

## 2. `.claude/VERSION` は `0.2.0` のまま据え置く（確定）

**flow-id 4-4 のレビューで「`0.2.0`」という判断を受けた。** AIの当初の提案は `1.0.0`（MAJOR）
だったが、**採用されなかった**。したがってこの計画では**`.claude/VERSION` を変更しない**。

- 現在値は **`0.2.0`**（main のマージで `0.1.2` → `0.2.0` になった。main 側の更新であり、
  このブランチは据え置いていた）。**この計画でも触らない。**
- **`AskUserQuestion` は行わない。** `distribution-assets.md`「増分の決め方」はAIが提案し人間が
  決めると定めており、**その決定は既に下りている**。実施時に重ねて聞かない。

### 据え置きに伴って必ずやること

`distribution-assets.md`「`.claude/VERSION`」節は、**据え置く場合はそのissueのspecのchangelogへ
据え置いた事実を残す**と定めている。これは任意ではない。

- **書く先は `【設計反映】` の成果物**（`distribution-assets.md` の `### issue #26` エントリ）で
  あり、この計画の成果物ではない。`【設計反映】` 側の計画にも同じ指示を書いてある。
- **据え置きには実害があることを承知したうえでの判断**である旨も併記する（同節が挙げている
  「配布先は同じ版のまま中身の違う `.claude/` を受け取るため、版から資産の差を判別できない」）。
  issue #26 は配布の仕組みそのものを入れ替えるので、この実害は過去のどの回よりも大きい。

### 却下された提案（記録として残す）

| 候補 | 根拠 | 結果 |
|---|---|---|
| `1.0.0`（MAJOR） | 旧方式で配られた `AGENTS.md` は `requiredLine` の一覧提示だけでは自動で直らず**手作業での移行が要る**ため、規定の `MAJOR`「配布先に手作業を要求する非互換変更」に当たる | **不採用** |
| `0.3.0`（MINOR） | 「資産の追加・フローの拡張」と読む場合 | 不採用 |
| **`0.2.0` のまま据え置き** | — | **採用**（flow-id 4-4） |

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

- **`.claude/VERSION` は変更しないので、配布先への影響も無い。** 当初は「上げるとテストを壊さないか」
  を検証項目に置いていたが、据え置きが確定したため**この検証は不要**になった。
  逆に、**検証5で `.claude/VERSION` に差分が出ていたら、この計画の範囲外の変更が混ざっている。**
- **`index.md` と `directory-structure.md` は役割が違う。** `index.md`（Repository Map）が
  ディレクトリの**役割説明**の正で、`directory-structure.md` は**ツリー構造・配置ルール**の正
  （`directory-structure.md` 冒頭に明記）。同じ説明文を両方へ書かないこと。
- **VERSIONを据え置くという判断も、`【設計反映】` の changelog へ書く必要がある。**
  上げないから何も書かなくてよい、ではない（`distribution-assets.md`「据え置く場合は、
  そのissueのspecのchangelogへ据え置いた事実を残す」）。**書く先はこの計画の成果物では
  ないので、`【設計反映】` を実施するときに漏らさないこと。**
- **1で追記するツリーの行のうち、新設 spec（`asset-distribution.md` 等）の分は
  `【設計反映】` が確定させたファイル名に依存する。** 計画時点では仮のため、
  実施時に実ファイル名を確認してから書く。
