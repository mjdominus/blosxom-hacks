
package Blosxom::MJD::Articles;
use base 'Exporter';
use Blosxom::MJD::Article;
use Blosxom::MJD::Path qw(article_dir);
use Carp qw(croak);
use File::Find;
use File::Spec;
our @EXPORT = qw(articles);

sub articles {
  my (%arg) = @_;
  my $top = delete $arg{section} || "";
  my $since = delete $arg{changed_since} || 0;
  my $status = delete $arg{status};
  if (%arg) {
    my $keys = join ", ", map qq{"$_"}, sort keys %arg;
    croak "Unknown argument(s) $keys to articles()";
  }

  my $root = File::Spec->catfile(article_dir(), $top);
  -d $root or croak "No such root directory as '$root'; aborting";

  my @articles;
  my $wanted = sub {
    return unless -f;
    my $article = Blosxom::MJD::Article->new($File::Find::name);
    return unless $article->last_modified > $since;
    return if defined($status) && ! $article->status_is($status);
    push @articles, $article;
  };
  find($wanted, $root);
  return @articles;
}

1;
