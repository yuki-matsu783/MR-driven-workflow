# UserUtteranceSelect.jq
#
# transcriptのJSONL（標準入力、-R -n + inputs で1行ずつ読む）から、人間の生発言を
# 抽出・選定・整形し、注入用の1セクション分のテキストと、除外イベント（累積カウント用）を
# まとめて1つのJSONオブジェクトとして返す。
#
# 起動:
#   jq -R -n -f UserUtteranceSelect.jq \
#     --arg branch "$branch" \
#     [--rawfile ack_words_raw <path> | --arg ack_words_raw ""] \
#     --argjson head_count N --argjson tail_count N --argjson max_bytes N \
#     < "$transcript_path"
#
# 出力:
#   {
#     "sectionText": "整形済みの注入用テキスト（空文字列なら何も注入しない）",
#     "excludedEvents": [{"uuid": "...", "word": "はい"}, ...],
#     "populationCount": 7
#   }
#
# 設計の正: wip/plans/【設計】【実装】【テスト】ユーザー発言抽出・再注入の実装.md

# UTF-8バイト数（jqのlengthはコードポイント数を返すため、コードポイントから算出する）
def utf8_bytes:
  explode
  | map(if . < 128 then 1 elif . < 2048 then 2 elif . < 65536 then 3 else 4 end)
  | add // 0;

# 前後の空白・句読点・感嘆符・記号を除去した正規化形
def normalize_text:
  gsub("^[\\s、。！？!?,.，．\\u3000]+"; "")
  | gsub("[\\s、。！？!?,.，．\\u3000]+$"; "");

# 前後の空白のみを除去する（正規化ほど強くない。スラッシュコマンド・タグ判定の前処理用）
def trim_ws:
  gsub("^\\s+"; "") | gsub("\\s+$"; "");

def ack_words:
  ($ack_words_raw // "")
  | split("\n")
  | map(gsub("\r$"; "") | gsub("^\\s+"; "") | gsub("\\s+$"; ""))
  | map(select((startswith("#") or (length == 0)) | not))
  | map(normalize_text);

def is_slash_command_only:
  test("^/[A-Za-z][A-Za-z0-9:_-]*$");

def is_tag_prefixed:
  test("^<[A-Za-z-]+");

# 1行をパースし、母集団条件を満たすものだけを整形して返す（満たさなければ空を返す）
def to_population_row:
  (try fromjson catch null) as $row
  | if $row == null then empty
    elif ($row.type // null) != "user" then empty
    elif (($row.message.content // null) | type) != "string" then empty
    elif ($row.userType // null) != "external" then empty
    # isSidechainはbool。`// null`はjqのfalsy判定でfalseもnullへ書き換えてしまうため使わない
    # （issue #151フェーズ3実装時に実際に踏んだ。falseの値がnullへ化けて全件が母集団から漏れた）。
    elif $row.isSidechain != false then empty
    elif (($row.origin.kind // null) != "human") then empty
    else {
      # uuidを持たない行が複数あると空文字列キーへ潰れ、重複除去で1件だけになってしまう
      # （issue #151フェーズ3敵対的レビュー2回目指摘）。行番号を一意な代替キーにする。
      uuid: ($row.uuid // ("line:" + (input_line_number | tostring))),
      gitBranch: ($row.gitBranch // null),
      text: $row.message.content
    }
    end;

# 内部の改行・連続空白を1つの半角スペースへ畳んでから切り出す。畳まないと複数行の発言が
# 箇条書きの構造を壊し、本文中の見出しらしき行（例: "## 次にやること"）が注入テキスト側の
# 本物の見出しと区別できなくなる（issue #151フェーズ3敵対的レビュー2回目指摘）。
def clip(head_chars; tail_chars):
  (. | gsub("\\s*\n\\s*"; " ")) as $s
  | ($s | length) as $len
  | if $len <= (head_chars + tail_chars) then $s
    else ($s[0:head_chars] + "…" + $s[($len - tail_chars):])
    end;

def render_bullets(rows):
  if (rows | length) == 0 then ""
  else "## 直近のユーザー発言（SessionStart hook）\n" + (rows | map("- 「" + .text + "」") | join("\n"))
  end;

# 箇条書き本文と除外内訳行を結合した、最終的なセクションテキストを組み立てる
def compose_section(bullets_text; excluded_line):
  if (bullets_text | length) > 0 then
    if (excluded_line | length) > 0 then bullets_text + "\n" + excluded_line
    else bullets_text
    end
  elif (excluded_line | length) > 0 then
    excluded_line
  else
    ""
  end;

# --- 母集団の確定 ---
[inputs | to_population_row] as $pop0
| (ack_words) as $words
# ブランチ絞り: 母集団の**いずれかの行**がgitBranchを持つ場合だけ、現在ブランチと一致する行へ絞る。
# 「一致が0件なら全件へフォールバック」ではない——全行がgitBranchを持つのに1件も一致しない場合
# （同一セッション内でブランチを切り替えた直後等）まで拾うと、別ブランチの発言が
# 「直近のユーザー発言」として無断で注入されてしまう（issue #151フェーズ3敵対的レビュー2回目指摘）。
# gitBranchを1件も持たない環境（Gemini CLI相当）でだけ、絞りようが無いので全件を対象にする。
| ($pop0 | map(select(.gitBranch != null))) as $with_branch
| (if ($with_branch | length) == 0 then $pop0
   else ($with_branch | map(select(.gitBranch == $branch)))
   end) as $pop1
# uuidによる重複除去（先勝ち）
| (reduce $pop1[] as $row ({seen: {}, list: []};
     if (.seen[$row.uuid] // false) then .
     else {seen: (.seen + {($row.uuid): true}), list: (.list + [$row])}
     end)).list as $pop2
| ($pop2 | length) as $population_count
# --- 除外規則の適用（除外してから採る） ---
| ($pop2 | map(
    . as $row
    | ($row.text | normalize_text) as $norm
    | ($row.text | trim_ws) as $trimmed
    | if ($words | index($norm)) != null then $row + {excludeReason: "dict", excludeWord: $norm}
      elif ($trimmed | is_slash_command_only) then $row + {excludeReason: "slash"}
      elif ($trimmed | is_tag_prefixed) then $row + {excludeReason: "tag"}
      else $row + {excludeReason: null}
      end
  )) as $marked
| ($marked | map(select(.excludeReason == null))) as $kept
| ($marked | map(select(.excludeReason == "dict"))) as $dict_excluded
| ($dict_excluded | map({uuid: .uuid, word: .excludeWord})) as $excluded_events
# --- 除外内訳行（辞書語のみ・件数集計）。バイト予算の判定にも使うため、採り方より先に確定する ---
| ($dict_excluded | reduce .[] as $e ({}; .[$e.excludeWord] = ((.[$e.excludeWord] // 0) + 1))) as $excluded_counts
| ( $excluded_counts | to_entries | map("\(.key)×\(.value)") | join(", ") ) as $excluded_line_body
| (if ($excluded_counts | length) == 0 then ""
   else "- 相槌等として除外: " + $excluded_line_body
   end) as $excluded_line
# --- 採り方: 先頭min(head_count,N) + 残りの末尾min(tail_count,N-head)（重複なし） ---
| ($kept | length) as $n
| ([$head_count, $n] | min) as $head_take
| ($kept[0:$head_take]) as $head_rows0
| ($kept[$head_take:]) as $rest
| ($rest | length) as $rest_n
| ([$tail_count, $rest_n] | min) as $tail_take
| (if $tail_take <= 0 then [] else $rest[($rest_n - $tail_take):] end) as $tail_rows0
# --- 切り出し ---
| ($head_rows0 | map({text: (.text | clip(120;40)), isHead: true})) as $head_out
| ($tail_rows0 | map({text: (.text | clip(80;30)), isHead: false})) as $tail_out
# --- バイト上限: 超えたら直近枠の古い側から1件ずつ落とす。判定対象は除外内訳行を含めた
#     節全体（issue #151フェーズ3敵対的レビュー2回目指摘。従来は箇条書き本文だけで判定していた）。
#     先頭枠は落とさない（先頭枠は上限より優先する方針。落とすと直近の現在地を最も表す発言が
#     消えてしまうため）。 ---
| (reduce range(0; ($tail_out | length) + 1) as $drop
    (null;
      if . != null then .
      else
        ($tail_out[$drop:]) as $cand_tail
        | (render_bullets($head_out + $cand_tail)) as $bullets
        | (compose_section($bullets; $excluded_line)) as $text
        | if ($text | utf8_bytes) <= $max_bytes then $cand_tail else null end
      end)
  ) as $fitted_tail
| (if $fitted_tail == null then [] else $fitted_tail end) as $final_tail
| ($head_out + $final_tail) as $selected
| (render_bullets($selected)) as $bullets_text
| (compose_section($bullets_text; $excluded_line)) as $section_text
| {
    sectionText: $section_text,
    excludedEvents: $excluded_events,
    populationCount: $population_count
  }
