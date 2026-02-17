package FCC::Action::Admin::DwndelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwndel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Profインスタンス
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db});
	#削除対象の識別ID
	my $dwn_id = $proc->{dwn}->{dwn_id};
	if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $dwn = $odwn->del($dwn_id);
	unless($dwn) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: dwn_id=${dwn_id}"];
		return $context;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
