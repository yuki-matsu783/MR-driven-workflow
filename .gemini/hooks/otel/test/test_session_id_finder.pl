#!/usr/bin/env perl
# SessionIdFinder::find_session_ids の単体テスト（issue #103）。
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use SessionIdFinder qw(find_session_ids);

# ネストの異なる複数箇所（リソース属性・ログレコード属性）からsession.idを収集できる
{
    my $payload = {
        resourceLogs => [{
            resource => { attributes => [{ key => 'session.id', value => { stringValue => 'sess-A' } }] },
            scopeLogs => [{
                logRecords => [{
                    attributes => [{ key => 'session.id', value => { stringValue => 'sess-B' } }],
                }],
            }],
        }],
    };
    my $found = find_session_ids($payload);
    is_deeply([ sort keys %$found ], [ 'sess-A', 'sess-B' ], 'ネストの異なる2箇所からsession.idを収集できる');
}

# 重複するsession.idは1つにまとまる
{
    my $payload = {
        a => { key => 'session.id', value => { stringValue => 'sess-X' } },
        b => { key => 'session.id', value => { stringValue => 'sess-X' } },
    };
    my $found = find_session_ids($payload);
    is_deeply([ sort keys %$found ], ['sess-X'], '同じsession.idは重複排除される');
}

# session.idが無い・空の場合
{
    is_deeply([ keys %{ find_session_ids({}) } ], [], 'session.idが無ければ空');
    is_deeply([ keys %{ find_session_ids([]) } ], [], '配列直下でも空');
    is_deeply([ keys %{ find_session_ids(undef) } ], [], 'undefでも空（クラッシュしない）');
}

# stringValueが空文字・欠落している場合は採用しない
{
    my $payload = {
        a => { key => 'session.id', value => { stringValue => '' } },
        b => { key => 'session.id', value => {} },
        c => { key => 'session.id' },
    };
    is_deeply([ keys %{ find_session_ids($payload) } ], [], '空文字・値欠落のsession.idは採用しない');
}

# key名が異なる属性は無視する（他の属性に紛れて誤検出しない）
{
    my $payload = { key => 'user.email', value => { stringValue => 'someone@example.com' } };
    is_deeply([ keys %{ find_session_ids($payload) } ], [], 'session.id以外のkeyは無視する');
}

done_testing();
