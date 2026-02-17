package FCC::Action::Admin::MbrdelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrdel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#削除対象の会員識別ID
	my $member_id = $proc->{member}->{member_id};
	if( ! defined $member_id || $member_id eq "" || $member_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $member = $omember->del($member_id);
	unless($member) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: member_id=${member_id}"];
		return $context;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
