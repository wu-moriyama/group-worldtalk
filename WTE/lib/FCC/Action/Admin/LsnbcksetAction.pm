package FCC::Action::Admin::LsnbcksetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "lsnmod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#払い戻し条件チェック
	my $lsn = $proc->{lsn};
	unless($lsn->{lsn_base_price} && $lsn->{lsn_base_price} > 0) {
		$context->{fatalerrs} = ["払い戻しができないレッスンです。"];
		return $context;
	}
	#払い戻し処理
	$proc->{errs} = [];
	my $lsn_id = $lsn->{lsn_id};
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $new_lsn = $olsn->pay_back($lsn_id);
	$proc->{lsn} = $new_lsn;
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
