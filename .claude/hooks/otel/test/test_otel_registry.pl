#!/usr/bin/env perl
# OtelRegistry の純粋関数（parse_registry_lines / needs_rotation / rotate_lines）の単体テスト
# （issue #103）。ファイルI/Oを伴う read_registry / append_registry_entry はここでは対象外
# （実機でのWindows/WSL動作確認で代替する）。
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use OtelRegistry qw(parse_registry_lines needs_rotation rotate_lines);

# --- parse_registry_lines ---

{
    my $lines = [
        qq({"schemaVersion":1,"session_id":"s1","cwd":"/repo/a"}\n),
        qq({"schemaVersion":1,"session_id":"s2","cwd":"/repo/b"}\n),
    ];
    my $map = parse_registry_lines(@$lines);
    is_deeply($map, { s1 => '/repo/a', s2 => '/repo/b' }, '正常な2行を読み込める');
}

{
    my $map = parse_registry_lines(
        qq({"schemaVersion":1,"session_id":"s1","cwd":"/repo/a"}\n),
        qq({"schemaVersion":2,"session_id":"s2","cwd":"/repo/b"}\n),
    );
    is_deeply($map, { s1 => '/repo/a' }, 'schemaVersionが不一致の行は無視する');
}

{
    my $map = parse_registry_lines(
        qq({"schemaVersion":1,"session_id":"s1","cwd":"/repo/a"}\n),
        qq(not json\n),
        qq(\n),
        qq({"schemaVersion":1,"session_id":"s2"}\n),
    );
    is_deeply($map, { s1 => '/repo/a' }, '壊れた行・空行・cwd欠落の行は無視する');
}

{
    # 同じsession_idが複数行あれば後勝ち（対応表は追記型なので最新のcwdを優先する）
    my $map = parse_registry_lines(
        qq({"schemaVersion":1,"session_id":"s1","cwd":"/repo/old"}\n),
        qq({"schemaVersion":1,"session_id":"s1","cwd":"/repo/new"}\n),
    );
    is_deeply($map, { s1 => '/repo/new' }, '同一session_idは後の行が勝つ');
}

{
    my $map = parse_registry_lines();
    is_deeply($map, {}, '行が無ければ空のマップ');
}

# --- needs_rotation / rotate_lines ---

{
    my @lines = map { "line$_\n" } (1 .. 500);
    ok(!needs_rotation(\@lines), '上限ちょうどの行数では切り詰め不要');
    push @lines, "line501\n";
    ok(needs_rotation(\@lines), '上限を1行超えると切り詰めが必要');
}

{
    my @lines = map { "line$_\n" } (1 .. 501);
    my $kept = rotate_lines(\@lines);
    is(scalar(@$kept), 300, '切り詰め後は既定の300行になる');
    is($kept->[0], "line202\n", '直近300行の先頭が正しい');
    is($kept->[-1], "line501\n", '直近300行の末尾が正しい');
}

{
    my @lines = map { "line$_\n" } (1 .. 10);
    my $kept = rotate_lines(\@lines, 3);
    is_deeply($kept, [ "line8\n", "line9\n", "line10\n" ], 'keep_linesを指定した切り詰めができる');
}

{
    my @lines = ("line1\n");
    my $kept = rotate_lines(\@lines);
    is_deeply($kept, \@lines, '上限未満なら変更しない');
}

done_testing();
