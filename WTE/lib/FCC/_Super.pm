package FCC::_Super;
$VERSION = 1.00;
use strict;
use warnings;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	bless $self, $class;
	$self->init(%args);
	return $self;
}

sub set {
	my($self, $name, $value) = @_;
	$self->{$name} = $value;
	return $value;
}

sub get {
	my($self, $name) = @_;
	return $self->{$name};
}

1;
