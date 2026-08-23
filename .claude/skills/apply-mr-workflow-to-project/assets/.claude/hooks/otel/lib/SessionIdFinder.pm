package SessionIdFinder;
# OTLP/JSON ペイロードを再帰的に走査し、session.id属性の値をすべて収集する純粋関数。
#
# OTLPのMetrics/Logs/Tracesはいずれもresource.attributes・scope配下のあちこちに
# 属性が付き、ネストの深さも信号種別ごとに異なる。決め打ちでパスをたどらず、
# JSON全体をキー"key"=="session.id"で全走査することで、信号種別・将来のスキーマ
# 変更に依存しない実装にしている（参考ディレクトリ/otel/listener.pyの移植）。
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = ('find_session_ids');

# $node: decode_jsonが返すHASH/ARRAY/スカラーのツリー
# 戻り値: 見つかったsession.idを重複無くHASHのキーとして返す（値は常に1）
sub find_session_ids {
    my ($node, $found) = @_;
    $found //= {};
    if (ref $node eq 'HASH') {
        if (exists $node->{key} && defined $node->{key} && $node->{key} eq 'session.id') {
            my $value = $node->{value};
            if (ref $value eq 'HASH' && defined $value->{stringValue} && length $value->{stringValue}) {
                $found->{ $value->{stringValue} } = 1;
            }
        }
        for my $v (values %$node) {
            find_session_ids($v, $found);
        }
    }
    elsif (ref $node eq 'ARRAY') {
        for my $v (@$node) {
            find_session_ids($v, $found);
        }
    }
    return $found;
}

1;
