package Blosxom::MJD::Article;
use Blosxom::MJD::MetaDB;
use Moose;

has file_path => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

has metadb => (
  is => 'ro',
  isa => 'Blosxom::MJD::MetaDB',
  default => sub {
    Blosxom::MJD::MetaDB->new(),
  },
  handles => [ qw(meta publication_date tags) ],
);

sub last_modified {
  (stat($_[0]->file_path))[9];
}

sub category {
  my @path = split m{/}, $_[0]->file_path;
}

sub notyet_path {
  my ($self) = @_;
  my $notyet = $self->file_path;
  $notyet =~ s/\.blog\z/.notyet/;
  return $notyet;
}

sub status {
  my ($self) = @_;
  -e $self->notyet_path ? 'notyet' : 'published';
}

sub status_is {
  my ($self, $desired_status) = @_;
  $self->status eq lc($desired_status);
}

no Moose;
1;
