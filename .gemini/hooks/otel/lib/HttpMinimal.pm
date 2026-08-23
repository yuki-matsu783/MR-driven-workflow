package HttpMinimal;
# IO::Socket::INET上で動く、HTTP/1.1リクエストの最小パーサ。
#
# CPANの HTTP::Daemon はコア添付ではなくインストールが要る（issue #103はコアモジュール
# のみに依存を限る方針。詳細: .claude/docs/spec/otel-listener.md）。
# Claude CodeのOTLP/HTTPエクスポータが送るのは単発のPOSTのみで、チャンク転送や
# keep-aliveへの対応は不要なため、リクエスト行・ヘッダ・Content-Length分のbodyを
# 読むだけの最小実装で足りる。
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = ('read_request', 'send_json_response');

# 1接続からHTTPリクエストを読み取る。
# 戻り値: { method => 'POST', path => '/v1/logs', headers => {lower-case key => value}, body => '...' }
# 接続が読み取り不能・リクエスト行が無い場合は undef を返す。
sub read_request {
    my ($client) = @_;

    my $request_line = <$client>;
    return undef unless defined $request_line;
    $request_line =~ s/\r?\n\z//;
    my ($method, $path) = $request_line =~ m{^(\S+)\s+(\S+)\s+HTTP/1\.[01]\z};
    return undef unless defined $method;

    my %headers;
    while (my $line = <$client>) {
        $line =~ s/\r?\n\z//;
        last if $line eq '';
        if ($line =~ /^([^:]+):\s*(.*)\z/) {
            $headers{ lc $1 } = $2;
        }
    }

    my $body = '';
    my $len = $headers{'content-length'} || 0;
    if ($len > 0) {
        my $read = read($client, $body, $len);
        $body = '' unless defined $read;
    }

    return { method => $method, path => $path, headers => \%headers, body => $body };
}

# JSON文字列をbodyとして200 OKで返す（本機構のレスポンスは常に固定の {} でよく、
# Claude Code側もレスポンスボディを解釈しない）。
sub send_json_response {
    my ($client, $status_code, $status_text, $body) = @_;
    $body = '{}' unless defined $body;
    print {$client} "HTTP/1.1 $status_code $status_text\r\n";
    print {$client} "Content-Type: application/json\r\n";
    print {$client} 'Content-Length: ' . length($body) . "\r\n";
    print {$client} "Connection: close\r\n";
    print {$client} "\r\n";
    print {$client} $body;
    return;
}

1;
