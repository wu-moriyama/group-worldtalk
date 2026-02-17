package FCC::Action::Admin::PrfaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Prof;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "prfadd" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("prfadd");

        #初期値
        $proc->{in} = {
            prof_status       => 1,
            prof_order_weight => 0,
            prof_reco         => 0,
            prof_coupon_ok    => 1,
			prof_override_margin => 0,
			normal_point_fee_rate => $self->{conf}->{normal_point_fee_rate},
			normal_point_prof_margin => $self->{conf}->{normal_point_prof_margin},
			normal_point_seller_margin => $self->{conf}->{normal_point_seller_margin},
			cancel1_point_fee_rate => $self->{conf}->{cancel1_point_fee_rate},
			cancel1_point_prof_margin => $self->{conf}->{cancel1_point_prof_margin},
			cancel1_point_seller_margin => $self->{conf}->{cancel1_point_seller_margin},
			cancel2_point_fee_rate => $self->{conf}->{cancel2_point_fee_rate},
			cancel2_point_prof_margin => $self->{conf}->{cancel2_point_prof_margin},
			cancel2_point_seller_margin => $self->{conf}->{cancel2_point_seller_margin},
			cancel3_point_fee_rate => $self->{conf}->{cancel3_point_fee_rate},
			cancel3_point_prof_margin => $self->{conf}->{cancel3_point_prof_margin},
			cancel3_point_seller_margin => $self->{conf}->{cancel3_point_seller_margin},
			normal_coupon_fee_rate => $self->{conf}->{normal_coupon_fee_rate},
			normal_coupon_prof_margin => $self->{conf}->{normal_coupon_prof_margin},
			normal_coupon_seller_margin => $self->{conf}->{normal_coupon_seller_margin},
			cancel1_coupon_fee_rate => $self->{conf}->{cancel1_coupon_fee_rate},
			cancel1_coupon_prof_margin => $self->{conf}->{cancel1_coupon_prof_margin},
			cancel1_coupon_seller_margin => $self->{conf}->{cancel1_coupon_seller_margin},
			cancel2_coupon_fee_rate => $self->{conf}->{cancel2_coupon_fee_rate},
			cancel2_coupon_prof_margin => $self->{conf}->{cancel2_coupon_prof_margin},
			cancel2_coupon_seller_margin => $self->{conf}->{cancel2_coupon_seller_margin},
			cancel3_coupon_fee_rate => $self->{conf}->{cancel3_coupon_fee_rate},
			cancel3_coupon_prof_margin => $self->{conf}->{cancel3_coupon_prof_margin},
			cancel3_coupon_seller_margin => $self->{conf}->{cancel3_coupon_seller_margin}
        };
        #
        $self->set_proc_session_data($proc);
    }

    #国選択肢リスト
    my $oprof        = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd}, pkey => $pkey, q => $self->{q} );
    my $country_list = $oprof->get_prof_country_list();
    #
    $context->{proc}         = $proc;
    $context->{country_list} = $country_list;
    return $context;
}

1;
