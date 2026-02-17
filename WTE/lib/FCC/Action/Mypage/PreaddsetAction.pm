package FCC::Action::Mypage::PreaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Prep;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
#	my $pkey = $self->{q}->param("pkey");
#	my $proc = $self->get_proc_session_data($pkey, "lsndtl");
#	if( ! $proc) {
#		$context->{fatalerrs} = ["不正なリクエストです。"];
#		return $context;
#	}
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
#	$proc->{errs} = [];
	my $pre = $opre->add({
		prof_id      => 0,
		member_id    => $member_id,
		lsn_id       => 0,
		prep_status  => 1,
		prep_content => $in->{prep_content}
	});
	#
#	$self->del_proc_session_data();
	return $context;
}

1;
