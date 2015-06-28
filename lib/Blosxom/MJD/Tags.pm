
package Blosxom::MJD::Tags;
use Blosxom::MJD::Meta;

sub get_tags {
  my ($path) = @_;
  return $self->meta->get_list($path, 'tags', { trim => 1 });
}

1;
