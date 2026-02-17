package FCC::Action::Seller::CpnmodfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "cpnmod");
	#
	unless($proc) {
		my $coupon_id = $self->{q}->param("coupon_id");
		if( ! defined $coupon_id || $coupon_id eq "" || $coupon_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("cpnmod");
		#クーポン情報を取得
		my $coupon = FCC::Class::Coupon->new(conf=>$self->{conf}, db=>$self->{db})->get_from_db($coupon_id);
		unless($coupon) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#代理店情報をチェック
		if($seller_id != $coupon->{seller_id}) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $coupon;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
