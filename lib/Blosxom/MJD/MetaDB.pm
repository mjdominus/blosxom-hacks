package Blosxom::MJD::MetaDB;
use Blosxom::MJD::Path;
use File::Spec;
use Moose;

with qw(Blosxom::MJD::FlatDB);

has db_path => (
  is => 'ro',
  isa => 'Str',
  default => sub {
    File::Space->catdir(Blosxom::MJD::Path::plugin_state_dir(), 'meta');
  }.
);

has db => (
  is => 'ro',
  isa => 'HashRef',
  default => { {} },
);



no Moose;
1;
