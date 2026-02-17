package FCC::Action::Admin::CpnaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Seller;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpnadd");
	unless($proc) {
		$proc = $self->create_proc_session_data("cpnadd");
		#代理店識別IDを取得
		my $seller_id = $self->{q}->param("seller_id");
		if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#代理店情報を取得
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{seller} = $seller;
		#初期値
		$proc->{in} = {
			seller_id => $seller_id,
			coupon_price => $self->{conf}->{coupon_price},
			coupon_max => $self->{conf}->{coupon_max},
			coupon_expire => $self->get_date_after_today($self->{conf}->{coupon_expire_days}),
			coupon_status => 1
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

sub get_date_after_today {
	my($self, $days) = @_;
	my $epoch = time + ( $days * 86400 );
	my @tm = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
	return "$tm[0]-$tm[1]-$tm[2]";
}

1;
