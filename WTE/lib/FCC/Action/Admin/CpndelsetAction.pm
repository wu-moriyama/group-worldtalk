package FCC::Action::Admin::CpndelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Coupon;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpndel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Couponインスタンス
	my $ocpn = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
	#削除対象の識別ID
	my $coupon_id = $proc->{in}->{coupon_id};
	if( ! defined $coupon_id || $coupon_id eq "" || $coupon_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $coupon = $ocpn->del($coupon_id);
	unless($coupon) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: coupon_id=${coupon_id}"];
		return $context;
	}
	$proc->{in} = $coupon;
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
