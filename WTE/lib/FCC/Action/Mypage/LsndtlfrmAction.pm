package FCC::Action::Mypage::LsndtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Msg;
use FCC::Class::Buzz;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#
	$self->del_proc_session_data();
	my $proc = $self->create_proc_session_data("lsndtl");
	$proc->{in} = {};
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
	if($lsn->{member_id} != $member_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#メッセージを取得
	my $omsg = new FCC::Class::Msg(conf=>$self->{conf}, db=>$self->{db});
	my $msg_res = $omsg->get_list({
		lsn_id => $lsn_id,
		offset => 0,
		limit => 100,
		sort   => [["msg_id", "DESC"]]
	});
	#my $msg_list = $msg_res->{list};
	my @msg_list = reverse(@{$msg_res->{list}});

	#クチコミを取得
	my $obuz = new FCC::Class::Buzz(conf=>$self->{conf}, db=>$self->{db});
	my $buz_res = $obuz->get_list({
		prof_id => $lsn->{prof_id},
		member_id => $member_id,
		offset => 0,
		limit => 100,
		sort   => [["buz_id", "DESC"]]
	});
	#my $buz_list = $buz_res->{list};
	my @buz_list = reverse(@{$buz_res->{list}});

	#レッスンが延長可能かどうかをチェック
	my $res = $olsn->is_extendable($lsn_id);
	$lsn->{lsn_extendable} = $res->{extendable};
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	$context->{lsn} = $lsn;
	$context->{msg_list} = \@msg_list;
	$context->{buz_list} = \@buz_list;
	return $context;
}


1;
