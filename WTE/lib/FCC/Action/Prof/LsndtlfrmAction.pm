package FCC::Action::Prof::LsndtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Msg;
use FCC::Class::Member;
use FCC::Class::Prep;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
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
	if($lsn->{prof_id} != $prof_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#会員情報を取得
	my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($lsn->{member_id});
	while( my($k, $v) = each %{$member} ) {
		$lsn->{$k} = $v;
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

	#進捗報告を取得
	my $opre = new FCC::Class::Prep(conf=>$self->{conf}, db=>$self->{db});
	my $prep_res = $opre->get_list({
#		lsn_id => $lsn_id,
		member_id => $lsn->{member_id},
		prep_status => 1,
		offset => 0,
		limit => 20,
		sort   => [["prep_id", "DESC"]]
	});
	my $prep_list = $prep_res->{list};
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	$context->{lsn} = $lsn;
	$context->{msg_list} = \@msg_list;
	$context->{prep_list} = $prep_list;
	return $context;
}


1;
