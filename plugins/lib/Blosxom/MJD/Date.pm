
package Blosxom::MJD::Date;
use Carp 'croak';
use Blosxom::MJD::Path;
use IO::Handle;
use Fcntl ':flock';

sub new {
  my $class = shift;
  my $file = shift
    || join "/", Blosxom::MJD::Path::plugin_state_dir(), "dates";
  open my($fh), "+<", $file or return;
  my $self = bless { fh => $fh, date => {} } => $class;
  $self->load_data && return $self;
}

sub load_data {
  my $self = shift;
  my $fh = $self->{fh};
  flock($fh, LOCK_SH) or return;
  $self->{last_mod} = (stat $fh)[9];

  while (<$fh>) {
    chomp;
    my ($date, $file) = split /\s+/, $_, 2;
    if (my ($y, $m, $d) = $date =~ /^(\d{4})-?(\d{2})-?(\d{2})$/) {
      require Time::Local;
      $date = Time::Local::timelocal(0,0,0, $y-1900, $m-1, $d);
    }
    $self->{date}{Blosxom::MJD::Path::trim_article($file)} = $date;
  }
  return 1;
}

sub check_lastmod {
  my $self = shift;
  $self->{last_mod} == (stat $self->{fh})[9]
    or croak "Optimistic locking failure; aborting";
}

sub save_data {
  my $self = shift;
  my $fh = $self->{fh};
  flock($fh, LOCK_EX) or return;
  $self->check_lastmod;
  seek($fh, 0, 0);
  truncate($fh, 0);
  my $dates = $self->{date};
  for my $art (sort keys %$dates) {
    my $path = Blosxom::MJD::Path::article_full_path($art);
    print $fh "$dates->{$art} $path\n";
  }
  return IO::Handle::flush($fh);
}

sub time_of {
  my ($self, $art) = @_;
  $self->{date}{Blosxom::MJD::Path::trim_article($art)};
}

sub set_time_of {
  my ($self, $art, $time) = @_;
  my $path = Blosxom::MJD::Path::trim_article($art);
  unless (exists $self->{date}{$path}) {
    croak "Can't set date for unknown article '$path'; aborting";
  }
  $self->{date}{$path} = $time;
}

sub set_date_of {
  my ($self, $art, $year, $mon, $day) = @_;
  defined($day) or die "Missing argument";
  require Time::Local;
  $self->set_time_of($art,
                     Time::Local::timelocal(0,0,0,$day, $mon-1, $year+1900));
}

sub year_of {
  my ($self, $art) = @_;
  my ($s, $m, $h, $d, $mo, $yr) = localtime($self->time_of($art));
  return $yr + 1900;
}

sub month_of {
  my ($self, $art) = @_;
  my ($s, $m, $h, $d, $mo, $yr) = localtime($self->time_of($art));
  return $mo + 1;
}

sub day_of {
  my ($self, $art) = @_;
  my ($s, $m, $h, $d, $mo, $yr) = localtime($self->time_of($art));
  return $d;
}

1;


