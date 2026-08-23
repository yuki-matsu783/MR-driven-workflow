#!/usr/bin/env bash
#
# 敵対的レビューの投稿件数選別（issue #182）。
#
# adversarial-review スキル手順6の確度×重大度による1次振り分け（投稿候補／報告のみ）は
# 変更しない。本スクリプトは、その1次振り分けを通過した「投稿候補」findingsに対し、
# 実際に何件投稿するかを次の層単位ルールで決定的に選別する。同じfindingsからは常に同じ
# 投稿集合が得られ、同一重大度内でどれを落とすかがAIエージェントの裁量にならないようにする。
#
#   1. blocker は全件投稿する（件数上限の対象外。単独で20件を超えても全件投稿し、
#      下位層は追加しない）。
#   2. blocker より下の層（major → minor）は、重大度の高い順に「層単位」で追加する。
#      層の途中では切らない。累計が10件（層追加のしきい値）に達した時点で、
#      それより下の層は追加しない。
#   3. 絶対上限（ハードシーリング）は20件。層を丸ごと追加すると累計が20件を超える場合に
#      限り、その層内を確度の降順→パスの昇順→行番号の昇順の決定的な順序で20件まで切る
#      （blockerはこの上限の対象外）。
#   4. 選ばれなかったfindingsは reported（報告のみ。会話・worklogへの書き出し）へ回す。
#
# 使い方:
#   bash .claude/scripts/src/select-adversarial-findings.sh <findings JSONファイル>
#
# 入力は {"findings":[{path,line,severity,confidence,...}, ...]} の形（1次振り分けを
# 通過した投稿候補。adversarial-reviewer サブエージェントのfindingsスキーマに準ずる）。
# 標準出力へ {"posted":{"findings":[...]},"reported":{"findings":[...]}} を出す。
# `posted.findings` はそのまま add_mr_inline_comments（Provider.sh）へ渡せる形。
#
# findingsは必ずファイル経由でjqへ渡す（jqの引数長上限を避けるため。
# .claude/rules/shell-script-style.md「JSON操作」）。jqの起動は1回に集約する。
#
# 層追加のしきい値（10）・ハードシーリング（20）は固定値。
# .claude/scripts/src/adversarial-review-count.sh の上限と同じ方針で、
# 緩める口は意図的に用意しない。

set -euo pipefail

LAYER_ADDITION_THRESHOLD=10
HARD_CEILING=20

# 選別ロジック本体（jqフィルタ）。
# - 層内の並び順は確度の降順（high→medium→low）→パスの昇順→行番号の昇順に統一する
#   （層を丸ごと追加する場合も含め、出力を常に決定的にするため）。
# - severityが blocker/major/minor のいずれでもないfinding（本来は上流の確度×重大度表で
#   除外されているはずのnit等）は、層の予算を消費せずそのまま reported へ回す（防御的な扱い）。
SELECT_FILTER='
def confidence_rank:
  if .confidence == "high" then 0
  elif .confidence == "medium" then 1
  elif .confidence == "low" then 2
  else 3 end;

def sort_key: [confidence_rank, (.path // ""), (.line // 0)];

def process_layer(th; cl; layer):
  . as $acc
  | (th) as $th
  | (cl) as $cl
  | (layer) as $layer
  | if ($acc.cum >= $th) then
      $acc + {reported: ($acc.reported + $layer)}
    else
      ($acc.cum + ($layer | length)) as $prospective
      | if ($prospective <= $cl) then
          $acc + {posted: ($acc.posted + $layer), cum: $prospective}
        else
          ($cl - $acc.cum) as $room
          | $acc + {
              posted: ($acc.posted + $layer[0:$room]),
              reported: ($acc.reported + $layer[$room:]),
              cum: $cl
            }
        end
    end;

. as $root
| ($root.findings // []) as $all
| ["blocker", "major", "minor"] as $known
| ($all | map(select(.severity as $sv | ($known | index($sv)) == null))) as $others
| (reduce $known[] as $sev
    ({}; . + {($sev): ($all | map(select(.severity == $sev)) | sort_by(sort_key))})
  ) as $bysev
| ({posted: $bysev.blocker, reported: [], cum: ($bysev.blocker | length)}
   | reduce ["major", "minor"][] as $sev (.; process_layer($threshold; $ceiling; $bysev[$sev]))
  ) as $final
| {posted: {findings: $final.posted}, reported: {findings: ($final.reported + $others)}}
'

# findings JSONファイルを読み、選別結果JSONを標準出力へ出す。
select_adversarial_findings() {
  local input_file="$1"
  jq -c \
    --argjson threshold "$LAYER_ADDITION_THRESHOLD" \
    --argjson ceiling "$HARD_CEILING" \
    "$SELECT_FILTER" \
    "$input_file"
}

main() {
  local input_file="${1:-}"

  if [ -z "$input_file" ]; then
    printf '使い方: %s <findings JSONファイル>\n' "$0" >&2
    return 1
  fi
  if [ ! -f "$input_file" ]; then
    printf 'ファイルが見つかりません: %s\n' "$input_file" >&2
    return 1
  fi

  select_adversarial_findings "$input_file"
}

# stdinを読む処理は無いが、テストから関数だけを読み込めるようにガードする
# （.claude/rules/shell-script-style.md「テスト」）。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
