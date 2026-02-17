package FCC::Action::Prof::PreaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Prep;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "lsndtl");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
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
	#入力値のname属性値のリスト
	my $in_names = [
		'prep_content'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my $opre = new FCC::Class::Prep(conf=>$self->{conf}, db=>$self->{db});
	my @errs = $opre->input_check($in_names, $in);
	#エラーハンドリング
	if(@errs) {
		$context->{fatalerrs} = [$errs[0]->[1]];
		return $context;
	}
	$proc->{errs} = [];
	my $pre = $opre->add({
		prof_id      => $prof_id,
		member_id    => $lsn->{member_id},
		lsn_id       => $lsn_id,
		prep_status  => 1,
		prep_content => $in->{prep_content}
	});
	#
	$self->del_proc_session_data();
	$context->{lsn_id} = $lsn_id;
	return $context;
}

1;
