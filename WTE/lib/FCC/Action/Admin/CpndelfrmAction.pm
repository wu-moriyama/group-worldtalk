package FCC::Action::Admin::CpndelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Coupon;
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpndel");
	unless($proc) {
		my $coupon_id = $self->{q}->param("coupon_id");
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
		#代理店情報を取得
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($coupon->{seller_id});
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $coupon;
		$proc->{seller} = $seller;
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
