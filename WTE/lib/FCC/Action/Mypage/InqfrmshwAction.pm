package FCC::Action::Mypage::InqfrmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "inq");
	#
	unless($proc) {
		$proc = $self->create_proc_session_data("inq");
		#会員情報を取得
		my $member_id = $self->{session}->{data}->{member}->{member_id};
		my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db});
		my $member = $omember->get_from_db($member_id);
		unless($member) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{member} = $member;
		#
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
