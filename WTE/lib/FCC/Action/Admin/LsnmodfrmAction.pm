package FCC::Action::Admin::LsnmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Msg;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "lsnmod");
	unless($proc) {
		#レッスン識別IDを取得
		my $lsn_id = $self->{q}->param("lsn_id");
		if( ! defined $lsn_id || $lsn_id eq "" || $lsn_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#レッスン情報を取得
		my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
		my $lsn = $olsn->get($lsn_id);
		if( ! $lsn ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("lsnmod");
		$proc->{lsn} = $lsn;
		$proc->{in} = {};
		$proc->{in}->{lsn_id} = $lsn_id;
		$self->set_proc_session_data($proc);
	}
	my $lsn = $proc->{lsn};
	my $lsn_id = $lsn->{lsn_id};
	#会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $member = $omember->get($lsn->{member_id});
	if($member) {
		while( my($k, $v) = each %{$member} ) {
			$lsn->{$k} = $v;
		}
	}
	#メッセージを取得
	my $omsg = new FCC::Class::Msg(conf=>$self->{conf}, db=>$self->{db});
	my $msg_res = $omsg->get_list({
		lsn_id => $lsn_id,
		offset => 0,
		limit => 100,
		sort   => [["msg_id", "ASC"]]
	});
	my $msg_list = $msg_res->{list};
	#
	$context->{proc} = $proc;
	$context->{lsn} = $lsn;
	$context->{msg_list} = $msg_list;
	return $context;
}


1;
