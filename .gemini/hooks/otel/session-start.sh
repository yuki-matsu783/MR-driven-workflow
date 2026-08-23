#!/usr/bin/env bash
# SessionStartフック: OTel対応表(session_id -> cwd)への追記と、リスナーの起動判定を行う。
# issue #103。参考ディレクトリ/otel/session-start.sh の移植（python3依存を排除しperlのみで書く）。
#
# ベストエフォート方針（設計判断8）: 途中の処理が失敗してもフック自体は必ず0で終了し、
# Claude Codeのセッション開始を妨げない。`set -e` は使わず、個別コマンドの失敗は握りつぶす。
set -u
cd "$(dirname "$0")" || exit 0

PORT="${OTEL_USAGE_PORT:-4318}"
SHARED_DIR="${CLAUDE_OTEL_SHARED_DIR:-${USERPROFILE:-${HOME:-.}}/.claude-otel}"
SHARED_DIR="${SHARED_DIR//\\//}"
REGISTRY_PATH="$SHARED_DIR/sessions.jsonl"

# stdinのJSON（Claude Codeが渡すhookイベント）からsession_id/cwdを拾い対応表へ追記する。
cat | OTEL_REGISTRY_PATH="$REGISTRY_PATH" perl -I lib -MOtelRegistry -e '
  local $/;
  my $raw = <STDIN>;
  my $data = eval { require JSON::PP; JSON::PP::decode_json($raw) };
  exit 0 unless ref $data eq "HASH";
  my $sid = $data->{session_id};
  my $cwd = $data->{cwd};
  exit 0 unless defined $sid && length $sid && defined $cwd && length $cwd;
  OtelRegistry::append_registry_entry($ENV{OTEL_REGISTRY_PATH}, $sid, $cwd);
' 2>/dev/null || true

# 既にリスナーが待ち受けていれば何もしない（/dev/tcp はbash組み込みで外部コマンド不要）
if (exec 3<>"/dev/tcp/127.0.0.1/${PORT}") 2>/dev/null; then
  exec 3<&- 2>/dev/null
  exec 3>&- 2>/dev/null
  exit 0
fi

# デタッチ起動。呼び出し元プロセスグループから切り離して常駐させる。
# Windows(git bash/MSYS)にはsetsidが無いため環境ごとに分岐する
# （reports/20260823_humming-mapping-pie_OTel設計論点調査.md「重要な発見」）。
LOG_PATH="$SHARED_DIR/listener.log"
mkdir -p "$SHARED_DIR" 2>/dev/null || true

if command -v setsid >/dev/null 2>&1; then
  OTEL_USAGE_PORT="$PORT" CLAUDE_OTEL_SHARED_DIR="$SHARED_DIR" \
    setsid nohup perl listener.pl >"$LOG_PATH" 2>&1 </dev/null &
else
  OTEL_USAGE_PORT="$PORT" CLAUDE_OTEL_SHARED_DIR="$SHARED_DIR" \
    nohup perl listener.pl >"$LOG_PATH" 2>&1 </dev/null &
fi
disown 2>/dev/null || true

exit 0
