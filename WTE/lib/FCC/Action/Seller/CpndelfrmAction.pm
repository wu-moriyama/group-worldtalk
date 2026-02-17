package FCC::Action::Seller::CpndelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Coupon;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpndel");
	my $coupon_id = $self->{q}->param("coupon_id");
	if( $coupon_id || ! $proc ) {
		if( ! defined $coupon_id || $coupon_id eq "" || $coupon_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("cpndel");
		#インスタンス
		my $ocpn = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
		#クーポン情報を取得
		my $coupon = $ocpn->get_from_db($coupon_id);
		unless($coupon) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#会員数を取得
		if($coupon->{coupon_num} > 0) {
			$context->{fatalerrs} = ["会員に登録されたクーポンを削除することはできません。"];
			return $context;
		}
		#代理店情報をチェック
		if($seller_id != $coupon->{seller_id}) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $coupon;
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
