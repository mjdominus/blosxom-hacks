# -*- cperl -*-

package Tie::File::Hash;
use Tie::File;
use strict;

sub TIEHASH {
  my ($class, $file, $args) = @_;
  my $sep = $args->{separator} || ": ";
  my $self = { sep => $sep };
  my @array;
  tie @array, 'Tie::File', $file, mode => $args->{mode} || 0
      or return;
  $self->{tf} = \@array;
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
  return unless defined $record;
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
    my $next = $self->{next_unknown};
    my ($k, $v) = $self->kv($next) or last;
    $self->{next_unknown}++;
    $self->{keyrec}{$k} = $next;
    return 1 if $k eq $key;
  }
  ++$self->{all_known};
  return;
}

sub STORE {
  my ($self, $k, $v) = @_;

  my $new_rec = join $self->{sep}, $k, $v;

  if ($self->found_key($k) || $self->find_key($k)) {
    $self->record($self->{keyrec}{$k}, $new_rec);
  } else {
    $self->{keyrec}{$k} = $self->append_rec($new_rec);
  }
}

sub append_rec {
  my ($self, $new_rec) = @_;
  push @{$self->{tf}}, $new_rec;
  return $#{$self->{tf}};
}

1;
