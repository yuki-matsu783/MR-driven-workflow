#!/usr/bin/env perl
# OTLP/JSON HTTPリスナー本体。
#
# Claude Code公式のOTLPエクスポータからのPOSTを受け、payload中のsession.id属性を
# 手がかりに、SessionStartフックが記録した対応表（OtelRegistry）から出力先
# ワークスペースを引いて `<cwd>/usage/claude-otel-YYYYMMDD.jsonl` へ追記する。
# session.idを引けなかった分は共有位置の `unrouted-YYYYMMDD.jsonl` へ退避する
# （参考ディレクトリ/otel/listener.py の移植。設計判断: plans/【設計】【実装】
# 【テスト】OTelリスナー機構の実装.md）。
#
# シングルスレッド・逐次accept方式。Claude Code 1インスタンスからのリクエストは
# 直列で来るため排他制御は不要（reports/20260823_humming-mapping-pie_OTel設計論点調査.md 5節）。
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use IO::Socket::INET;
use JSON::PP ();
use POSIX qw(strftime);

use HttpMinimal qw(read_request send_json_response);
use SessionIdFinder qw(find_session_ids);
use OtelRegistry qw(read_registry);

my $port      = $ENV{OTEL_USAGE_PORT} || 4318;
my $shared_dir = $ENV{CLAUDE_OTEL_SHARED_DIR} || _default_shared_dir();
my $registry_path = "$shared_dir/sessions.jsonl";

$| = 1;

my $server = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => 16,
    ReuseAddr => 1,
) or die "listen失敗(port=$port): $!\n";

print "listening on 127.0.0.1:$port\n";

while (my $client = $server->accept()) {
    $client->autoflush(1);
    my $ok = eval { handle_connection($client); 1 };
    warn "handle_connection failed: $@" unless $ok;
    close($client);
}

sub handle_connection {
    my ($client) = @_;
    my $req = read_request($client);
    unless ($req) {
        return;
    }
    unless ($req->{method} eq 'POST') {
        send_json_response($client, 404, 'Not Found', '{}');
        return;
    }

    my $payload = eval { JSON::PP::decode_json($req->{body}) };
    $payload = { raw => $req->{body} } unless ref $payload;

    route_and_write($payload);

    send_json_response($client, 200, 'OK', '{}');
    return;
}

sub route_and_write {
    my ($payload) = @_;

    my $table = read_registry($registry_path);
    my $sids  = find_session_ids($payload);

    my %targets;
    for my $sid (keys %$sids) {
        my $cwd = $table->{$sid};
        next unless defined $cwd && length $cwd;
        $targets{"$cwd/usage/" . _output_filename()} = 1;
    }

    my $record = {
        ts      => strftime('%Y-%m-%dT%H:%M:%S%z', localtime),
        payload => $payload,
    };

    if (%targets) {
        for my $target (keys %targets) {
            _append_best_effort($target, $record);
        }
    }
    else {
        _append_best_effort("$shared_dir/" . _unrouted_filename(), $record);
    }
    return;
}

sub _append_best_effort {
    my ($path, $record) = @_;
    my $ok = eval {
        my $dir = $path;
        $dir =~ s{[/\\][^/\\]*\z}{};
        if (length $dir && ! -d $dir) {
            require File::Path;
            File::Path::make_path($dir);
        }
        open(my $fh, '>>:encoding(UTF-8)', $path) or die "open failed: $!";
        print {$fh} JSON::PP::encode_json($record) . "\n";
        close $fh;
        1;
    };
    if (!$ok) {
        # 出力先にも書けない場合はベストエフォートで諦める（受け口を落とさないことを優先。
        # reports/…md「ベストエフォート方針の実現方法」節）。
        warn "failed to write otel record to $path: $@";
    }
    return;
}

sub _output_filename {
    return 'claude-otel-' . strftime('%Y%m%d', localtime) . '.jsonl';
}

sub _unrouted_filename {
    return 'unrouted-' . strftime('%Y%m%d', localtime) . '.jsonl';
}

sub _default_shared_dir {
    # Windows(git bash)ではUSERPROFILE、WSL/LinuxではHOMEを使う
    # （設計判断2: 共有位置の具体パス）。
    my $home = $ENV{USERPROFILE} || $ENV{HOME} || '.';
    $home =~ s{\\}{/}g;
    return "$home/.claude-otel";
}
