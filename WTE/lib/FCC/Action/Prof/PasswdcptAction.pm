package FCC::Action::Prof::PasswdcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッションデータをコピー
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "passwd");
	my $in = {};
	while( my($k, $v) = each %{$proc->{in}} ) {
		$in->{$k} = $v;
	}
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#ログアウト処理
	$self->{session}->logoff();
	#
	$context->{in} = $in;
	return $context;
}

1;
