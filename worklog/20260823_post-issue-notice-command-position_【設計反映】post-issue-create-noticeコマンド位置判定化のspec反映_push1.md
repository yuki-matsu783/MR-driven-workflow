# worklog: 【設計反映】post-issue-create-notice.shコマンド位置判定化のspec反映（push1）

対象: issue #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（2026-08-23）。
全体作業計画: `plans/post-issue-notice-command-position.md`
個別反映計画: `plans/【設計反映】post-issue-create-noticeコマンド位置判定化のspec反映.md`

## 試したこと

- flow-id 4-1: 個別反映計画を作成した（初版はcommand-position.md 4箇所・issue-mr-workflow.md
  1箇所のみ）。敵対的レビュー（フェーズ4・1回目/最大3回。計画レビュー）で13件の指摘
  （blocker 1件・major 8件・minor 3件・nit 1件）を受け、計画を大幅に改訂した（反映対象を
  command-position.md 9箇所・issue-mr-workflow.md 2箇所へ拡大、DDR `i0149-01`新設、
  `shell-script-style.md`への反映を追加）。詳細は計画md「敵対的レビュー（1回目・計画レビュー）を
  踏まえた改訂」節。
- flow-id 4-6: 改訂後の計画に沿って反映を実施した。
  - `command-position.md`: 利用元・公開インターフェース表・判定の3段（§1縮退判定式の違い・
    §3相違点リスト・§4保守的フォールバック）・呼び出し側の責務節（3段ガードの2つの型）・
    既知の制約表・未決定事項・影響範囲・frontmatterを更新。
  - `issue-mr-workflow.md`: 「検知の条件」表・「既知のトレードオフ」節を更新。
  - `.claude/docs/ddr/i0149-01-…md`を新規作成し、`generate-ddr-list.sh`でREADME.mdへ反映した。
  - `.claude/rules/shell-script-style.md`へAIアセット反映（1箇所）。
  - `CommandPosition.sh`のコメント誤字を1箇所修正（ロジック無変更）。
- 敵対的レビュー（フェーズ4・2回目/最大3回。実装レビュー）を実施し、9件の指摘（major 1件・
  minor 6件・nit 2件）を受けた。すべて反映した。
  1. major: 既知の制約表のクォートパス行が「インタプリタを介さない直接起動は依然として
     見逃す」ことを書いていない → 行を2つに分割し、直接起動形式の既知の制約を明記。
  2. minor: DDR「理由5」の「検知漏れを解消した」が実装より強い → 「インタプリタ経由の形に
     ついて」と限定し、直接起動は既知の制約として残る旨を追記。却下案表3行目も整合させた。
  3. minor: `_CP_PREFIX_OPTS_WITH_VALUE`の一律適用による検知漏れ（`sudo -n`/`command -p`/
     `env -i`が対象スクリプトを値として読み飛ばし見逃す）が書かれていない → 既知の制約表へ
     新規行を追加。
  4. minor: 前置フィルタの超集合性の根拠が主張を支えていない（既存テストケースは判定本体を
     通らない）→ 根拠を「前置フィルタ無変更」「共通の正規化関数を経由」の2点へ差し替え、
     突き合わせテストが無く設計上の推論に留まる旨を明記。
  5. minor: テストのコメントが古い記述（トップレベル3段ガード実行済み・現行CLI経路判定は
     単純な部分一致）のまま → 型B（遅延初期化）・コマンド位置判定への差し替え済みに合わせて
     2箇所書き換え。
  6. minor: 変数代入チェックの順序差がscript版とgit版の相違点リストに漏れている → 相違点
     リストへ1項目追加。
  7. minor: issue-mr-workflow.mdの追記が型Bの理由を重複して書いている（4箇所目）→
     command-position.md「型B」節への参照のみに整理。
  8. minor: 「計測上+35%」に測定条件が添えられていない → 「性能」節へ測定条件
     （100回・同一セッション・Linux・ライブラリ不在相当との比較）を追記。
  9. nit: 既知の制約表を行番号（「7〜8行目」「9行目」）で指している → 類型名で指す表現へ
     書き換え。
  10. nit: DDRのファイル名とtitle・本文見出しが一致していない（`.sh`の有無）→
      ファイル名を`i0149-01-post-issue-create-notice.shの検知をコマンド位置判定へ移行する.md`
      へ改名し、title・本文見出しと一致させた（README.mdも`generate-ddr-list.sh`で再生成）。

## うまくいったこと

- `bash -n`構文チェック・`test_command_position.sh`（118件）・`test_post_issue_create_notice.sh`
  （38件）・`test_block_direct_git_commit.sh`（27件）すべて`failures=0`（レビュー2回目の
  指摘反映後も回帰なし）。
- DDRファイルの改名後も`generate-ddr-list.sh`の再生成で`.claude/docs/README.md`のDDR一覧が
  正しく更新されることを確認した。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 4-7: commit・push してレビュー依頼を行う。
- フェーズ4の敵対的レビューは2回実施済み（最大3回）。3回目を追加で回すかは、今回の修正が
  レビュー指摘への対応（新規の反映対象追加ではない）であることを踏まえて判断する。
- 落ち着いたらフェーズ5（クローズ）へ進む。

---
