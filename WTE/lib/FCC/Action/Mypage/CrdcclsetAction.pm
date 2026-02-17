package FCC::Action::Mypage::CrdcclsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Card;

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
	#入力値のname属性値のリスト
	my $in_names = [
		'crd_id',
		'member_id'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my $err = 0;
	if($in->{crd_id} != $proc->{in}->{crd_id} || $in->{member_id} != $proc->{in}->{member_id}) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#cardsレコードを取得
	my $ocard = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
	my $card = $ocard->get($in->{crd_id});
	if( ! $card ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	$ocard->del($in->{crd_id});
	#
	$context->{proc} = $proc;
	return $context;
}

1;
