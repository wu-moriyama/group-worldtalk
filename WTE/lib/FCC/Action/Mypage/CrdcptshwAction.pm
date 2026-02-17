package FCC::Action::Mypage::CrdcptshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($proc->{in}->{confirm_ok} != 1) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#プロセスセッションデータをコピー
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crd");
	my $in = {};
	while( my($k, $v) = each %{$proc->{in}} ) {
		$in->{$k} = $v;
	}
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#
	$context->{in} = $in;
	return $context;
}

1;
