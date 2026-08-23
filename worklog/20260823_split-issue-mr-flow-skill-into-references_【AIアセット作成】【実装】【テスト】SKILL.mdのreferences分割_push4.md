---
title: worklog — SKILL.mdのreferences分割（push4）
type: log
description: フェーズ3〈作業〉の個別作業計画作成と、切り出しスクリプトの事前検証の記録
tags: [worklog, issue-mr-flow, skill]
keywords: [切り出しスクリプト, 見出し一致, 参照列, flow-id解決, mawk, frontmatter, skill-reference]
---

# worklog: 【AIアセット作成】【実装】【テスト】SKILL.mdのreferences分割

対象: SKILL.md を本文と `references/` 8ファイルへ切り出し、読むタイミングを機械的に決める（2026-08-23）。
全体作業計画: `plans/split-issue-mr-flow-skill-into-references.md`
個別作業計画: `plans/【AIアセット作成】【実装】【テスト】SKILL.mdのreferences分割.md`
push回数: 4

## 試したこと

- **切り出しスクリプトの事前検証**（フェーズ2のレビュー待ち中に用意し、フェーズ3で使う）。
  H2/H3の見出し位置から各行の行き先を決め、行の切り貼りだけで8ファイルへ分ける。
  `assert seen == list(range(1, len(lines)+1))` で漏れ・重複が無いことを表明する。
  - dry-run の結果: body 144行 / references 7ファイル、合計1447行（末尾の空行を含む数え方）。
  - **元の SKILL.md の見出し62件と、切り出し後の本文＋`references/*.md` の見出しが集合として
    完全一致することを確認した**（`git show "$base":…SKILL.md` を基準にした）。
- **現在地flow-id解決の関数**（`current_flow_id_to_reply`）を、`update-handoff-progress.sh` の
  `parse_table_row_to_reply` と同じ正規表現で試作し、実際の `HANDOFF.md` に対して実行した。
- **参照列抽出の関数**（`refs_for_flow_id_to_reply`）を、`参照` 列を足したサンプル表に対して試作した。

## うまくいったこと

- 切り出しは**見出し62件が完全一致**した。「本文を1文字も書き換えない」という宣言を、
  機械的に確かめられる形にできた（計画の検証 #2）。
- 現在地flow-id解決は、進捗表の更新に追随して正しい値を返した。本ブランチの `HANDOFF.md` を
  2-2完了まで進めた状態で `2-2`、その後 `2-5`・`2-10` を完了させた状態で次の `[]` を返す。
  **「最初の `[]` を採る」方式なら `1-5` を返し続けるところで、方式の違いが実データで確認できた。**
- 参照列抽出は、存在しないflow-id（`9-9`）に対して空を返す（fail-open）ことも確認した。
- `type` の値は **`skill-reference` を新設**する方針にした。既存の `skill` を流用すると
  `doc-search --type skill` が9件から17件へ増え、「スキルを一覧する」という問いの答えが変わってしまう。

## ダメだったこと

- **HANDOFF.md の進捗表が実作業に追いついていなかった**（2-2以降が `[]` のまま、フェーズ2の
  実作業だけが進んでいた）。`.claude/rules/docs-workflow.md` は「flow-idが1つ進むごとに更新し、
  commitより前に行って同じcommitへ含める」と定めているのに、まとめて後から直すことになった。
  - **今回は `mark-done` を使って一度に揃えたが、2-6〜2-9 は人間レビュー（2-8）を含むループ範囲
    なので、規約に従って `[]` へ戻した。** `mark-done` はループ範囲を丸ごと `[x]` にするため、
    非対話環境では意図と食い違う。
- **敵対的レビューの投稿件数が上限（10件）を2回連続で超えた**（1回目11件、2回目11件）。
  投稿前に件数を数える手順が自分の中に無かった。提出済みレビューは削除できない。

## 次の一歩

- flow-id 3-2: commit・push してレビュー依頼。
- 敵対的レビュー（フェーズ3・1回目）を本計画に対して実施する。**投稿前に件数を数える。**
- flow-id 3-6: 作業1〜7を実施する。着手順は「作業1（切り出し）→ 作業2・3（本文への追加）→
  作業7（frontmatter/type）→ 作業4（hook）→ 作業6（実行時メッセージ・テスト）→ 作業5（参照追従）」。
  参照追従を最後に置くのは、それまでに `references/` の最終的なファイル名が確定するため。

## 追記（敵対的レビュー フェーズ3・1回目とその対応）

- 個別作業計画に対して敵対的レビューを実施。**検出19件**（blocker 1 / major 8 / minor 10）。
  選別表に従い**10件をインラインへ投稿**（今回は投稿前に件数を数え、ちょうど10件で提出した）。
  報告のみ9件はPRの単発コメントに一覧で残した。
- **19件すべてを計画md・htmlへ反映した。** 主な設計変更:
  - 「本文は1文字も書き換えない」→「**切り貼り以外で触らない＋例外は参照の付け替えのみ**
    （全件をreports/へ列挙し、検証#2の全行差分と突き合わせる）」へ言い換え（指摘#2・#7）。
  - `describe` 抽出の終端に `/^## /` を追加する方針を明記（指摘#1。mawkが `{n,m}` を
    解釈しない可能性があるため `/^#{2,3} /` は使わない）。
  - 正規表現の共有は `source` をやめ、**同一リテラルの複製＋一致テスト**へ（指摘#8。
    `set -e` の持ち込みと `main` 衝突で fail-open が壊れるため）。
  - `review-loop.md` へ導入H2を補い、`get_vcs_access_mode` の前提を再掲（指摘#9）。
  - `format_skill_reload_instruction` の呼び出しは**2箇所**（hook本体とテスト287行）。
    第2引数は `"${2:-}"` の既定値付きで受ける（指摘#4・#11）。
  - 検証へ #13（アンカーリンク）・#14（相対参照）を追加、#1に行数、#2をcomm二段構え、
    #9・#10に実行可能な形の条件を追記（指摘#3・#5・#12・#13・#15）。

## 追記（flow-id 3-5〜3-6: description更新と作業1〜7の実施）

- flow-id 3-5: PR #161 の description を更新した（フェーズ3計画の要約と実装状況）。
- **mainのマージ**: PR #162 マージで origin/main が進み `HANDOFF.md` がコンフリクト。
  「1ブランチ1状態」のファイルなのでブランチ側を採って解消（監視モード例外・検証は省略せず）。
- flow-id 3-6: 作業1〜7を予定の順（1→2・3→7→4→6→5）で実施した。詳細と検証14項目の結果は
  `reports/20260823_split-issue-mr-flow-skill-into-references_作業.md` が正文。
- **うまくいったこと**: 検証14項目すべて合格。ミューテーションテスト（旧パスへ戻すと
  `failures=1`）で「変え忘れ検出」が実際に働くことまで確認できた。
- **想定と異なった点**（計画からの逸脱。レポートにも記録）:
  1. 検証#2-(i) の増分は8件ではなく**9件**（対応表自身のH2を数え漏れ。計画を訂正）。
  2. 導入H2は「H1の直後」ではなく「`### comments` の直前」へ（切り出し結果の先頭は
     「敵対的レビューの位置づけ」のH2だったため）。
  3. `references/` 配下は**7ファイル**（本文と合わせて8。計画の「references/配下の8ファイル」
     という表記を訂正）。
  4. 配布物へ `index.jsonl`（生成物）が混入する既存問題を発見（残課題・別issue候補）。

## 切り出しスクリプト全文（作業1で使用。再現用）

```python
#!/usr/bin/env python3
"""SKILL.md を本文と references/*.md へ機械的に切り出す（issue #160 フェーズ3の下ごしらえ）。

本文を1文字も書き換えないことを保証するため、**行の切り貼りだけ**で行う。
節の割り当ては SECTIONS で定義し、それ以外の加工はしない（見出しの追加・リンクの張り替えは
このスクリプトの後で人手（Edit）で行う）。

使い方:
    python3 split_skill.py --dry-run     # 割り当てと行数だけを出す
    python3 split_skill.py --out DIR     # DIR へ body.md と references/*.md を書き出す
"""
import argparse
import os
import re
import sys

SRC = ".claude/skills/issue-mr-flow/SKILL.md"

# H2見出しの本文（`## ` を除いた文字列）→ 行き先。
# "body" は SKILL.md 本文に残す。それ以外は references/ 配下のファイル名。
SECTIONS = {
    "全体フロー": "SPLIT",  # H3単位でさらに分ける（下記 H3_SECTIONS）
    "PR/MR作成・マージの担当（flow-id 1-3・5-5・5-6）": "body",
    "敵対的レビューの位置づけ（issue #77）": "references/review-loop.md",
    "サブコマンド": "SPLIT_SUB",
    "`gh`/`glab` CLI不在時のMCPフォールバック": "references/mcp-fallback.md",
    "チャットで受けたレビュー判断の記録（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）": "references/review-loop.md",
    "レビュー依頼メッセージ（全体フロー 2-2・2-7・3-2・3-7・4-2・4-7・5-3・5-5）": "references/review-loop.md",
    "レビュー完了合図の確認（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）": "references/review-loop.md",
    "作業開始・再開時のベースブランチ追従確認（issue #67）": "references/start-resume.md",
    "PR作成後のdefaultブランチ追従（監視）（flow-id 1-3〜5-6を横断）": "references/base-branch-followup.md",
    "defaultブランチとのコンフリクト検知・解消（flow-id 5-1）": "references/base-branch-followup.md",
    "マージ前の関連issue通知（flow-id 5-2）": "references/phase5-close.md",
    "最終統括レポートとPR/MRへの反映（flow-id 5-3）": "references/phase5-close.md",
    "PRがflow-id 5-4実施前にマージされてしまった場合の対処": "references/phase5-close.md",
    "詳細ルールへのポインタ": "body",
    "前提": "body",
}

# 「全体フロー」節の中のH3。導入＋42行テーブル（最初のH3の手前まで）は body。
H3_SECTIONS = {
    "全体作業計画に必ず含めるフェーズ（issue #92）": "references/planning.md",
    "計画の2階層構造（issue #9）": "references/planning.md",
    "issueが大きすぎる場合の分割提案（issue #64）": "references/planning.md",
    "計画と実施結果の分離（issue #87）": "references/deliverables.md",
    "計画・レポートのHTMLビュー（issue #54）": "references/deliverables.md",
}

# 「サブコマンド」節の中のH3。導入は references/start-resume.md（経路判定の注意書きなので
# 両方から参照される。フェーズ3で本文へ要約を置く）。
H3_SUBCOMMANDS = {
    "`start <issue番号>` — issue取得・ブランチ/MR作成（全体フロー 1-2〜1-3）": "references/start-resume.md",
    "`comments [all]` — MRレビューコメントの取得（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）": "references/review-loop.md",
    "`reply <threadId> <対応内容>` — レビューコメントへの返信（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）": "references/review-loop.md",
    "`describe` — MR descriptionの更新（全体フロー 2-5・2-10・3-5・3-10・4-5・4-10）": "references/review-loop.md",
    "`sync` — セッション再開（全体フロー 1-3の再開版）": "references/start-resume.md",
    "`resume` — 途中引き継ぎ（引数なし）": "references/start-resume.md",
}
SUBCOMMAND_INTRO = "references/start-resume.md"


def headings(lines):
    """フェンス外の見出しを (行番号1始まり, レベル, 本文) で返す。"""
    out, fence = [], False
    for i, ln in enumerate(lines, 1):
        if ln.startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = re.match(r"^(#{1,6}) (.+)$", ln)
        if m:
            out.append((i, len(m.group(1)), m.group(2)))
    return out


def assign(lines):
    """各行の行き先を決めて {行き先: [行番号...]} を返す。frontmatter とH1直下の前文は body。"""
    heads = headings(lines)
    h2 = [(i, t) for i, lv, t in heads if lv == 2]
    if not h2:
        sys.exit("H2見出しが見つからない")

    owner = ["body"] * (len(lines) + 1)  # 1始まり

    for idx, (start, title) in enumerate(h2):
        end = h2[idx + 1][0] - 1 if idx + 1 < len(h2) else len(lines)
        dest = SECTIONS.get(title)
        if dest is None:
            sys.exit(f"未定義のH2: {title!r}（SECTIONS へ追加すること）")

        if dest == "SPLIT":
            sub = [(i, t) for i, lv, t in heads if lv == 3 and start < i <= end]
            first = sub[0][0] if sub else end + 1
            for n in range(start, first):
                owner[n] = "body"
            for j, (s, t) in enumerate(sub):
                e = sub[j + 1][0] - 1 if j + 1 < len(sub) else end
                d = H3_SECTIONS.get(t)
                if d is None:
                    sys.exit(f"未定義のH3（全体フロー内）: {t!r}")
                for n in range(s, e + 1):
                    owner[n] = d
        elif dest == "SPLIT_SUB":
            sub = [(i, t) for i, lv, t in heads if lv == 3 and start < i <= end]
            first = sub[0][0] if sub else end + 1
            for n in range(start, first):
                owner[n] = SUBCOMMAND_INTRO
            for j, (s, t) in enumerate(sub):
                e = sub[j + 1][0] - 1 if j + 1 < len(sub) else end
                d = H3_SUBCOMMANDS.get(t)
                if d is None:
                    sys.exit(f"未定義のH3（サブコマンド内）: {t!r}")
                for n in range(s, e + 1):
                    owner[n] = d
        else:
            for n in range(start, end + 1):
                owner[n] = dest

    buckets = {}
    for n in range(1, len(lines) + 1):
        buckets.setdefault(owner[n], []).append(n)
    return buckets


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    lines = open(SRC, encoding="utf-8").read().split("\n")
    buckets = assign(lines)

    total = 0
    for dest in sorted(buckets):
        body = "\n".join(lines[n - 1] for n in buckets[dest])
        b = len(body.encode("utf-8"))
        total += b
        print(f"{dest:<40} {len(buckets[dest]):>5}行 {b:>7}バイト")
    print(f"{'合計':<40} {sum(len(v) for v in buckets.values()):>5}行 {total:>7}バイト")

    # 行の取りこぼし・重複が無いことを表明する
    seen = sorted(n for v in buckets.values() for n in v)
    assert seen == list(range(1, len(lines) + 1)), "行の割り当てに漏れか重複がある"
    print("行の割り当て: 漏れ・重複なし")

    if a.dry_run or not a.out:
        return
    for dest, nums in buckets.items():
        path = os.path.join(a.out, "SKILL.md" if dest == "body" else dest)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines[n - 1] for n in nums))
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
```

## 敵対的レビュー（フェーズ3・2回目=作業結果）と flow-id 3-9 対応

- サブエージェントが16件を検出（major 5 / minor 9 / nit 2）。カウンタ increment → 2/3。
- マトリクス選別: 投稿10件（ちょうど上限。うち2件は行がdiffハンク外のためファイルコメント）、
  報告のみ6件（単発コメントで投稿）。投稿前にハンク範囲をローカルdiffで確認した。
- 対応（全16件）:
  - test_session_start.sh: 末尾空行の検証をファイル＋`tail -c 2`非空判定へ（コマンド置換が
    末尾改行を全て落とすため従来形は常に成功していた）。`\|`列ずれ・旧表記`[x][x][]`・
    2参照併記のフィクスチャ追加。実HANDOFF.md/実SKILL.md全42行の実データ回帰を追加。
    tmp_handoff_dirをTMP_DIR配下へ集約（trap上書きで後片付けが無効になっていた）。
    **テストのラベルにバッククォートを書いて `/` が実行される事故**を1回踏んだ
    （`assert_eq "… \` / \` …"` の二重引用符内バッククォートはコマンド置換になる。
    ラベルは単一引用符にするか「 」で書く）。
  - session-start.sh: 参照列抽出値の形検証（fail-open）・注入時の完全パス化・旧表記ガード・
    ROW_RE複製コメントの根拠を set -euo pipefail の1点へ修正。
  - 変異テスト3種（空行混入・検証無効化・旧表記ガード無効化）で各 failures=1 を確認し復元。
  - SKILL.md: 参照列（5-3/5-5→review-loop.md、1-6→planning.md）、参照列の設計注記
    （mcp-fallback.mdは参照列で指さずhookが経路判定で注入）、担当列説明へreview-loop.md、
    対応表前文へ新設H2・見出しレベル調整の明記。
  - references/: 係り先を失った指示語3件を修正、review-loop.mdの前提再掲をリンク1行へ、
    planning.md/deliverables.mdの見出しをH3/H4→H2/H3へ1段上げ。
  - test_install_to_project.sh: 配布先references/*.mdの本家との集合一致を表明（passed=24）。
  - directory-structure.md（表・ツリー図）・index.md: references/ の実例を追記（フェーズ4予定を前倒し）。
- 全テスト16本 passed=1028 failures=0。
