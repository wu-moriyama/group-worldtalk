package FCC::Action::Prof::TopAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Prof;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $prof = $oprof->get_from_db($prof_id);
	$context->{prof} = $prof;
	return $context;
}

1;
