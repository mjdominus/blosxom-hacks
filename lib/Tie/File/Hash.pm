# -*- cperl -*-

package Tie::File::Hash;
use Tie::File;

sub new {
  my ($class, $file, $args) = @_;
  my $sep = qr($args->{separator} || ": ");
  my $self = { sep => $sep };
  $self->{tf} = Tie::File->new($file, $args->{mode} || 0)
    or return;
  $self->{keyrec} = {}; # maps keys to record numbers
  $self->{next_unknown} = 0; # next unexamined record
  $self->{all_known} = 0;    # no more unexamined records
  bless $self => $class;
}

sub FETCH {
  my ($self, $key) = @_;
  unless ($self->found_key($key)) {
    $self->find_key($key) or return;
  }
  return $self->value($self->{keyrec}{$key});
}

sub found_key {
  my ($self, $key) = @_;
  defined $self->{keyrec}{$key};
}

sub kv {
  my ($self, $n) = @_;
  my $record = $self->record($n);
  my ($key, $val) = split /\Q$self->{sep}/, $record, 2;
  return ($key, $val);
}

sub record {
  my ($self, $n, $new) = @_;
  if (@_ > 2) {
    return $self->{tf}[$n] = $new;
  } else {
    return $self->{tf}[$n];
  }
}

sub value {
  my ($self, $n) = @_;
  my ($k, $v) = $self->kv($n);
  return $v;
}

sub find_key {
  my ($self, $key) = @_;
  return if $self->{all_known};
  while (1) {
    my $next = $self->{next_unknown}++;
    my ($k, $v) = $self->kv($next) or last;
    $self->{keyrec}{$k} = $next;
    return 1 if $k eq $key;
  }
  ++$self->{all_known};
  return;
}

1;
