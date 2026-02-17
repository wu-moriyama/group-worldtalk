package FCC::Action::Preg::CfmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Preg::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "preg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#国選択肢リスト
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	my $country_hash = $oprof->get_prof_country_hash();
	#
	$context->{proc} = $proc;
	$context->{country_hash} = $country_hash;
	return $context;
}

1;
