package FCC::Action::Mypage::CrdcfmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Plan;
use FCC::Class::Card;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'pln_id'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my @errs;
	if( ! $in->{pln_id} ) {
		push(@errs, ["pln_id", "プランを選択してください。"]);
	} else {
		my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
		my $pln = $opln->get($in->{pln_id});
		if($pln) {
			while( my($k, $v) = each %{$pln} ) {
				$in->{$k} = $v;
			}
		} else {
			push(@errs, ["pln_id", "不正な値が送信されました。"]);
		}
	}
	#
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		$proc->{in}->{confirm_ok} = 1;
		$proc->{in}->{member_id} = $member_id;
		$proc->{in}->{crd_price} = $proc->{in}->{pln_price};
		$proc->{in}->{crd_point} = $proc->{in}->{pln_point};
		$proc->{in}->{crd_subscription} = $proc->{in}->{pln_subscription};
		$proc->{in}->{crd_ref} = 0;
		my $ocard = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
		my $card;
		if($proc->{in}->{crd_id}) {
			if($proc->{in}->{crd_success}) {
				#プロセスセッションを削除
				$self->del_proc_session_data();
				$context->{fatalerrs} = ["もう一度やり直してください。"];
				return $context;
			} else {
				$card = $ocard->mod($proc->{in});
			}
		} else {
			$card = $ocard->add($proc->{in});
		}
		while( my($k, $v) = each %{$card} ) {
			$proc->{in}->{$k} = $v;
		}
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
