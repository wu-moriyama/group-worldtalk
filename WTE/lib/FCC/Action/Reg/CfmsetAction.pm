package FCC::Action::Reg::CfmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Reg::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Coupon;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "reg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_lastname',
		'member_firstname',
		'member_handle',
		'member_email',
		'member_pass',
		'member_pass2',
		'coupon_code'
	];
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $omember->input_check($in_names, $proc->{in});
	my $coupon_code = $proc->{in}->{coupon_code};
	if($coupon_code ne "") {
		if($coupon_code !~ /^[a-zA-Z0-9]{8}$/) {
			push(@errs, ["coupon_code", "ご指定のクーポンはご利用になれません。"]);
		} else {
			my $ocoupon = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
			my $coupon = $ocoupon->get_from_db_by_code($coupon_code);
			if( ! $coupon || ! $coupon->{coupon_available} ) {
				push(@errs, ["coupon_code", "ご指定のクーポンはすでにご利用頂くことができなくなりました。"]);
			} else {
				$proc->{in}->{coupon_price} = $coupon->{coupon_price};
			}
		}
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
