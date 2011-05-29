
package Blosxom::MJD::Path;
use base 'Exporter';
@EXPORT_OK = qw(trim_article article_dir plugin_dir plugin_state_dir);

sub trim_article {
  my $art = shift;
  my $ADIR = article_dir();
  $art =~ s/^$ADIR\///o;
  $art;
}

sub article_full_path {
  my $art = shift;
  my $ADIR = article_dir();
  return $art =~ m{^/} ? $art : "$ADIR/$art";
}

sub article_dir {
  "/home/mjd/misc/blog/entries";
}

sub plugin_dir {
  "/home/mjd/src/perl/blosxom/plugins"
}

sub plugin_state_dir {
  "/home/mjd/src/perl/blosxom/plugins/state"
}

