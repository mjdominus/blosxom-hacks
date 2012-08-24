#!/usr/bin/perl

use Test::More;
use Test::Deep;
use Tie::File::Hash;
use Fcntl;

plan tests => 15;
my $file = "/tmp/tiefile$$";

{
    ok(tie %f, 'Tie::File::Hash', $file, { mode => O_RDWR | O_CREAT });
    for (1..3) {
	# Insert new records
	$f{$_} = $_ * $_;
    }
    for (1..3) {
	# mutate old records
	is($f{$_}, $_ * $_);
	$f{$_} = $_ + 1;
    }
    for (1..3) {
	is($f{$_}, $_ + 1);
    }
}
untie %f;

{
    my @data = do { open my ($fh), "<", $file or die; <$fh> };
    is_deeply(\@data, [ "1: 2\n", "2: 3\n", "3: 4\n" ], "raw file data");
}

{
    ok(tie %f, 'Tie::File::Hash', $file, { mode => O_RDWR | O_CREAT });
    for (3, 2) {
	# mutate old records
	is($f{$_}, $_ + 1);
	$f{$_} = "foo$_";
    }
    $f{"11"} = "eleven";
    is ($f{1}, 2);
    is ($f{11}, "eleven");
    is ($f{2}, "foo2");

    note "do gaps get closed up after delete?";
    delete $f{11};
    delete $f{2};
    $f{2} = "newfoo2";
    untie %f;

    open my($fh), "<", $file or die $!;
    my $BLANK_LINES = 0;
    while (<$fh>) { $BLANK_LINES++ if $_ =~ /^$/ }
    is($BLANK_LINES, 0, "this many blank lines not closed up after untie");
}

END { unlink $file }
