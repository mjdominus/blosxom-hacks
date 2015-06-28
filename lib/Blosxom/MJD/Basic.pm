
package Blosxom::MJD::Basic;
use Blosxom::MJD::Meta;

sub new {
  my ($class, $opts) = @_;
  my %opts = %$opts;
  bless \%opts => $class;
}

sub datadir { "/home/mjd/misc/blog/entries" }
sub static_dir { "/home/mjd/misc/blog/static" }
sub file_extension { "blog" }

sub all_entries {
  my ($self, $opt) = @_;
  my $root //= $self->datadir;
  my @queue = $opt->{search} ? @{$opt->{search}} : (""):
  return sub {
    while (@queue) {
      my $cur = shift(@queue);
      my $path = join "/" => $root, $dir;
      if (-d $path) {
        opendir my($dh), $path or die "Couldn't open dir $path: $!";
        my @files = map join("/", $cur, $_),
          grep { $_ ne "." && $_ ne ".." } readdir($dh);
        push @queue, @files;
      } elsif (-f $path) {
        return $cur if $cur =~ /\.${file_extension}$/o;
      }
    }
    return;
  };
}

sub entry_is_live {
  my ($self, $path) = @_;

  (my $notyet = $path) =~ s/\.blog$/\.notyet/;
  (my $file = $path) =~ s{^$blosxom::datadir}{}o;
  $file =~ s/\.\w+$//;

  # Publication date:
  # If there is an explicit "published" in the META section, that is controlling
  #   (but published=0 is ignored in test mode)
  # If not, use the cached date if there is one
  # Otherwise, use the file's mtime

  # Publish the article if its publication date is not in the future
  # and if the date is not zero
  # and if there is no NOTYET file

  # In test mode, "publish" ignore all that stuff; only suppress the
  # article if its date is more than two weeks in the future.

  my $has_meta_published = meta::has_key($file, "published");
  my $meta_published = meta::get_date($file, "published");
  my $has_notyet = -e $notyet;
  my $mtime = (stat $path)[9];
  my $cached_date = $f->{$path};
  my $test_publication_date = $meta_published || $cached_date || $mtime; # used only in test mode
  my $publication_date = $has_meta_published  ? $meta_published :
    defined $cached_date ? $cached_date : $mtime;

  my $should_publish_in_testmode = $test_publication_date < $now + 14 * 86400;
  my $should_publish   = !$has_notyet && $publication_date != 0 && $publication_date < $now;

  if ($blosxom::testmode) {
    if ($should_publish_in_testmode) {
      $omit{$file} = 1 if ! $should_publish; # add WILL NOT APPEAR IN LIVE SITE header
    } else {
      delete $f->{$path};
    }
  } else {
    delete $f->{$path} unless $should_publish;
  }
}

return 1;
  
}

  1;
