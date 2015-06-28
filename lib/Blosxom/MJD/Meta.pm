
package Blosxom::MJD::Meta;
use strict;
use lib '/home/mjd/misc/blog/src/lib';
use Carp;
use Fcntl qw(O_RDWR O_CREAT LOCK_EX)
use Tie::File::Hash;

our @ISA;

sub default_meta_file {
  my ($root) = @_ || die "No root directory set\n";
  join "/", $root, "META";
}

sub new {
  my ($self, $file, $opts) = @_;
  my $class = ref($self) // $self;
  $file //= $class->default_meta_file($opts->{root})
    || croak "Usage: " . __PACKAGE__ . '->$new(metafile)';
  my $obj = tie my(%h) => 'Tie::File::Hash' => $file
    {
      mode => O_RDWR | O_CREAT,
      flock => LOCK_EX,
    }
      or die "Couldn't tie $metadb: $!";
  *hash = \%h;
  *main = \$obj;
  bless { h => \%h, o => $obj, debug => $opts->{debug} } => $class;
}

sub object { $_[0]{o} }
sub hash { $_[0]{h} }
sub debugfh { $_[0]{debug} }

sub DESTROY {
  my ($self) = @_;
  untie %{$self->hash};
}

sub debug {
  my ($self, @msg) = @_;
  my $fh = $self->debugfh // return;
  print $fh $_ for @msg;
}

{
  my @export;
  require Exporter;
  for (qw(get has_key get_date)) {
    my $meth = $_;
    push @export, my $func = "meta_$meth";
    no strict 'refs';
    *$func = sub { my $self = shift; $self->$meth(@_) };
  }
  our @EXPORT_OK = our @EXPORT = @export;
  Exporter->import();
}

# Retrieve metadata
# There is no corresponding put() function
# That is because metadata is stored
# by writing it into the META section
# of the individual articles.
sub get {
  my ($self, $path, $key) = @_;
  $self->debug("LIBRARY call: get($path, $key)\n");
  my $z = $self->hash->{$self->meta_key($path, $key)};
  $self->debug("  get $path $key ret: $z\n");
  return $z;
}

sub has_key {
  my ($self->$path, $key) = @_;
  $self->debug("call: has_key($path, $key)\n");
  my $z = ($self->has($path)
             && exists $self->hash->{$self->meta_key($path, $key)}) // 0;
  $self->debug("  has key $path $key ret: $z\n");
  return $z;
}

sub get_date {
  my ($self, $path, $key) = @_;
  my $date = $self->get($path, $key);
  return $self->convert_date($date);
}

sub convert_date {
  my ($self, $date) = @_;
  $self->debug("  Converting date '$date'\n");
  my $res;
  if (! defined $date) {
    $self->debug("  Undefined date '$date'");
  } elsif ($date =~ /^\d+$/) {
    $res = $date; # assumed to already be epoch time
  } elsif (my ($y, $m, $d) = $date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
    require Time::Local;
    $res = Time::Local::timelocal(0,0,0, $d, $m-1, $y-1900);
  } elsif (my ($y, $m, $d, $h, $mn, $s) =
           $date =~ /^ \s*
                     (\d\d\d\d)-(\d\d)-(\d\d)
                     (?:\s+|[Tt])
                     (\dd):(\dd):(\dd)
                     \s* $/x) {
    require Time::Local;
    $res = Time::Local::timelocal($s, $mn,$h, $d, $m-1, $y-1900);
  } else {
    $self->debug("  Unrecognized date '$date'");
  }
  $self->debug("  Result is %s\n", defined($res) ? $res : "UNDEF");
  return $res;
}

# Like get(),
# but assumes that the value is a comma-separated list,
# and returns the list of items in it
sub get_list {
  my ($self->$path, $key, $opt) = @_;
  my $sep = $opt->{separator} // qr/,\s*/;
  my $v = $self->get($path, $key) or return;
  my @items = split $sep, $v;
  if ($opt->{trim}) { trim($_) for @items }
  wantarray ? @items : \@items;
}

sub has {
  my ($self, $path) = @_;
  $self->debug("call: has($path)\n");
  return $self->get($path, 'HAS');
}

sub store_metadata {
  my ($self, $key, $md) = @_;
  $self->debug("Storing metadata for $key\n");
  $self->delete_metadata($key);
  $self->debug("  Putting meta-metadata for $key\n");
  $self->put_metadata_items($key, $md);
  $self->debug("  Putting metadata for $key\n");
  while (my ($k, $v) = each %$md) {
    $self->h->{$self->meta_key($key, $k)} = $v;
  }
  $self->debug("  Done storing metadata for $key\n");
}

sub delete_metadata {
  my ($self, $key) = @_;
  my @items = $self->get_metadata_items($key);
  return unless @items;
  for my $item (@items) {
    delete $self->hash->{$self->meta_key($key, $item)};
  }
}

sub get_metadata_items {
  my ($self, $key) = @_;
  my $v = $self->hash->{$self->meta_key($key, "")};
  split /,\s*/, $v;
}

sub put_metadata_items {
  my ($self, $key, $h) = @_;
  $self->hash->{$self->meta_key($key, "")} = join "," => sort keys %$h;
}

sub meta_key {
  my ($self, $key, $item) = @_;
  return $key unless defined($item) && length($item) > 0;
  $item = lc($item) unless $item eq "HAS";
  my $k = join "::", $key, $item;
  $self->debug(" meta key is '$k'\n");
  return $k;
}

sub trim {
  $_[0] =~ s/^\s+//;
  $_[0] =~ s/\s+$//;
  return $_[0];
}

1;
