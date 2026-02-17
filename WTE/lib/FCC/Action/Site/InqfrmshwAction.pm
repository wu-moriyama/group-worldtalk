package FCC::Action::Site::InqfrmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Site::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#会員ログイン済みなら会員メニューへリダイレクト
	if( $self->{session}->{data} && $self->{session}->{data}->{member_id} ) {
		$context->{redirect} = $self->{conf}->{ssl_host_url} . "/WTE/mypage.cgi?m=inqfrmshw";
		return $context;
	}
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "inq");
	#
	unless($proc) {
		$self->{session}->create();
		$proc = $self->create_proc_session_data("inq");
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
