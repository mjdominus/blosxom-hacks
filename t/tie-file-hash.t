#!/usr/bin/perl

use Test::More;
use Tie::File::Hash;
use Fcntl;

plan tests => 7;

ok(tie %f, 'Tie::File::Hash', "/tmp/tiefile$$", { mode => O_RDWR | O_CREAT });
for (1..3) {
  $f{$_} = $_ * $_;
}
for (1..3) {
  is($f{$_}, $_ * $_);
  $f{$_} = $_ + 1;
}
for (1..3) {
  is($f{$_}, $_ + 1);
}
untie %f;
note "file /tmp/tiefile$$";
