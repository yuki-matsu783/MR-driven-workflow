package OtelRegistry;
# session_id -> cwd の対応表（sessions.jsonl相当）の読み書き。
#
# 純粋関数（parse_registry_lines / needs_rotation / rotate_lines）と、
# それらを呼び出すファイルI/O層（read_registry / append_registry_entry）を分ける。
# 単体テスト（test/test_otel_registry.pl）は純粋関数のみを対象にする。
use strict;
use warnings;
use Exporter 'import';
use JSON::PP ();
use Fcntl qw(:flock);

our @EXPORT_OK = (
    'parse_registry_lines', 'needs_rotation', 'rotate_lines',
    'read_registry', 'append_registry_entry',
);

# 複数リポジトリ・複数バージョンのOTel機構を同時運用したときに、対応表の行が
# どのバージョンで書かれたか判別できるようにする（フェーズ2持ち越し事項1）。
our $SCHEMA_VERSION = 1;
our $MAX_LINES       = 500; # このユーザーの`session-start.sh`実行のたびに1回チェックする
our $KEEP_LINES       = 300;

# --- 純粋関数（副作用なし） ---

# 行配列（各行はJSON文字列、末尾改行の有無は問わない）から session_id => cwd のマップを作る。
# schemaVersionが一致しない行・壊れた行は静かに無視する（他バージョン・他プロセスとの共存のため）。
sub parse_registry_lines {
    my (@lines) = @_;
    my %map;
    for my $line (@lines) {
        my $trimmed = $line;
        $trimmed =~ s/\r?\n?\z//;
        next unless length $trimmed;
        my $entry = eval { JSON::PP::decode_json($trimmed) };
        next unless ref $entry eq 'HASH';
        next unless defined $entry->{schemaVersion} && $entry->{schemaVersion} == $SCHEMA_VERSION;
        next unless defined $entry->{session_id} && length $entry->{session_id};
        next unless defined $entry->{cwd} && length $entry->{cwd};
        $map{ $entry->{session_id} } = $entry->{cwd};
    }
    return \%map;
}

# 行数が上限を超えたか（$max_linesは省略時$MAX_LINES）
sub needs_rotation {
    my ($lines, $max_lines) = @_;
    $max_lines //= $MAX_LINES;
    return scalar(@$lines) > $max_lines;
}

# 直近$keep_lines行だけを残す（$keep_linesは省略時$KEEP_LINES）
sub rotate_lines {
    my ($lines, $keep_lines) = @_;
    $keep_lines //= $KEEP_LINES;
    return $lines if @$lines <= $keep_lines;
    return [ @{$lines}[ -$keep_lines .. -1 ] ];
}

# --- ファイルI/O層 ---

my %CACHE; # path => { mtime => ..., map => {...} }

# 対応表を読み込む。mtimeが前回と同じならキャッシュを返す（起動のたびに全行を
# パースし直さないため。listener.plはリクエストのたびに呼ぶので効く）。
sub read_registry {
    my ($path) = @_;
    my @st = stat($path);
    return {} unless @st;
    my $mtime = $st[9];
    my $cache = $CACHE{$path};
    return $cache->{map} if $cache && $cache->{mtime} == $mtime;

    open(my $fh, '<:encoding(UTF-8)', $path) or return $cache ? $cache->{map} : {};
    my @lines = <$fh>;
    close $fh;
    my $map = parse_registry_lines(@lines);
    $CACHE{$path} = { mtime => $mtime, map => $map };
    return $map;
}

# 対応表へ1行追記し、肥大化していれば直近だけへ切り詰める。
# ベストエフォート方針: 書き込みに失敗しても呼び出し元（session-start.sh）を
# 落とさないよう、例外は投げず真偽値を返すだけにする。
sub append_registry_entry {
    my ($path, $session_id, $cwd) = @_;
    return 0 unless defined $session_id && length $session_id;
    return 0 unless defined $cwd && length $cwd;

    my $dir = $path;
    $dir =~ s{[/\\][^/\\]*\z}{};
    if (length $dir && ! -d $dir) {
        my $ok = eval { require File::Path; File::Path::make_path($dir); 1 };
        return 0 unless $ok;
    }

    my $ok = eval {
        open(my $fh, '>>:encoding(UTF-8)', $path) or die "open failed: $!";
        flock($fh, LOCK_EX);
        my $line = JSON::PP::encode_json({
            schemaVersion => $SCHEMA_VERSION,
            session_id    => $session_id,
            cwd           => $cwd,
        });
        print {$fh} $line . "\n";
        flock($fh, LOCK_UN);
        close $fh;
        1;
    };
    return 0 unless $ok;

    _rotate_if_needed($path);
    return 1;
}

sub _rotate_if_needed {
    my ($path) = @_;
    eval {
        open(my $fh, '<:encoding(UTF-8)', $path) or die "open failed: $!";
        my @lines = <$fh>;
        close $fh;
        return unless needs_rotation(\@lines);
        my $kept = rotate_lines(\@lines);
        open(my $out, '>:encoding(UTF-8)', "$path.tmp") or die "open tmp failed: $!";
        print {$out} @$kept;
        close $out;
        rename("$path.tmp", $path) or die "rename failed: $!";
        1;
    };
    return;
}

1;
