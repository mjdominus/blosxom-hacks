#!/usr/bin/perl
use Test::More;

my $BLOSXOM = "./blosxom.cgi";
my $blog_title = "The Universe of Discourse";

is(title_for("/"), $blog_title, "main page");
is(title_for("/math/koan.html"),
   qq{$blog_title : On the consistency of PA},
   "article page");
is(title_for("/talk"), $blog_title, "talk archive page");
is(title_for("/2005"), $blog_title, "2005 archive page");
done_testing;

sub title_for {
  my ($path) = @_;
  local $ENV{PATH_INFO} = $path;
  my $html = qx{./blosxom.cgi};
  my ($title) = $html =~ m{<title>(.*)</title>}s;
  return $title;
}
