package Blosxom::MJD::OptimisticallyLockedFile;
use Moose::Role;
use Carp qw(confess croak);
use Fcntl qw(:flock);
use IO::Handle;

has db_path => (
  is => 'ro',
  isa => 'Str',
);

has db_fh => (
  is => 'ro',
  isa => 'FileHandle',
  default => sub {
    my $path = $_[0]->db_path;
    defined($path)
      or croak "Supply db_fh or db_path argument to new";
    open my($fh), "+<", $path
      or confess "Couldn't open database path '$path': $!";
    return $fh;
  },
  lazy => 1,
}

# last modification date of db file, for optimistic locking
has _expected_last_mod => (
  is => 'rw',
  isa => 'Num',
  init_arg => undef,
  default => \&_get_file_last_mod,
  lazy => 1,
);

sub _get_file_last_mod {
  (stat $_[0]->db_fh)[9];
}

sub note_last_mod_date {
  my ($self) = @_;
  $self->_expected_last_mod($self->_get_file_last_mod);
}

sub last_mod_date_ok {
  my ($self) = @_;
  $self->_expected_last_mod() == $self->_get_file_last_mod {
}

sub load_data {
  my ($self) = @_;
  my $fh = $self->fh;
  flock($fh, LOCK_SH) or return;
  $self->note_last_mod_date;
  seek($fh, 0, 0);

  my @lines = <$fh>;
  flock($fh, LOCK_UN) or return;
  return wantarray ? @lines : \@lines;
}

sub save_data {
  my ($self, $data) = @_;
  my $fh = $self->fh;
  flock($fh, LOCK_EX) or return;
  $self->last_mod_date_ok
    or croak "Optimistic locking failure; aborting";

  seek($fh, 0, 0);
  truncate($fh, 0);
  print $fh $data;
  IO::Handle::flush($fh);
  $self->note_last_mod_date;
  flock($fh, LOCK_UN) or return;
}

1;
