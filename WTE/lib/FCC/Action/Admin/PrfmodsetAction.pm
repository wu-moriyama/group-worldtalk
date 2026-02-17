package FCC::Action::Admin::PrfmodsetAction;
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
    my $proc = $self->get_proc_session_data( $pkey, "prfmod" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #入力値のname属性値のリスト
    my $in_names = [
        'prof_company',            'prof_dept',                  'prof_title',                   'prof_lastname',           'prof_firstname',             'prof_handle',
        'prof_email',              'prof_pass',                  'prof_skype_id',                'prof_logo',               'prof_order_weight',          'prof_reco',
        'prof_rank',               'prof_coupon_ok',             'prof_zip1',                    'prof_zip2',               'prof_addr1',                 'prof_addr2',
        'prof_addr3',              'prof_addr4',                 'prof_tel1',                    'prof_tel2',               'prof_tel3',                  'prof_hp',
        'prof_audio_url',          'prof_video_url',             'prof_birthy',                  'prof_birthm',             'prof_birthd',                'prof_gender',
        'prof_country',            'prof_residence',             'prof_character',               'prof_interest',           'prof_associate1',            'prof_associate2',
        'prof_intro',              'prof_intro2',                'prof_memo',                    'prof_memo2',              'prof_status',                'prof_logo_up',
        'prof_logo_del',           'prof_app1',                  'prof_app2',                    'prof_app3',               'prof_app4',                  'prof_override_margin',
        'normal_point_fee_rate',   'normal_point_prof_margin',   'normal_point_seller_margin',   'cancel1_point_fee_rate',  'cancel1_point_prof_margin',  'cancel1_point_seller_margin',
        'cancel2_point_fee_rate',  'cancel2_point_prof_margin',  'cancel2_point_seller_margin',  'cancel3_point_fee_rate',  'cancel3_point_prof_margin',  'cancel3_point_seller_margin',
        'normal_coupon_fee_rate',  'normal_coupon_prof_margin',  'normal_coupon_seller_margin',  'cancel1_coupon_fee_rate', 'cancel1_coupon_prof_margin', 'cancel1_coupon_seller_margin',
        'cancel2_coupon_fee_rate', 'cancel2_coupon_prof_margin', 'cancel2_coupon_seller_margin', 'cancel3_coupon_fee_rate', 'cancel3_coupon_prof_margin', 'cancel3_coupon_seller_margin'
    ];

    # FCC:Class::Profインスタンス
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd}, pkey => $pkey, q => $self->{q} );

    #入力値を取得
    my @multiple_item_list = ( 'prof_character', 'prof_interest' );
    my $in                 = $self->get_input_data( $in_names, \@multiple_item_list );
    while ( my ( $k, $v ) = each %{$in} ) {
        $proc->{in}->{$k} = $v;
    }
    for my $k (@multiple_item_list) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $proc->{in}->{$k} } ) {
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        $proc->{in}->{$k} = unpack( "N", pack( "B32", $bits ) );
    }

    unless ( $in->{prof_pass} ) {
        delete $in->{prof_pass};
        delete $proc->{in}->{prof_pass};
        my @new_in_names;
        for my $k ( @{$in_names} ) {
            if ( $k ne "prof_pass" ) {
                push( @new_in_names, $k );
            }
        }
        $in_names = \@new_in_names;
    }

    #入力値チェック
    my @errs = $oprof->input_check( $in_names, $proc->{in}, "mod" );

    #エラーハンドリング
    if (@errs) {
        $proc->{errs} = \@errs;
    }
    else {
        $proc->{errs} = [];
        my $rec = {};
        while ( my ( $k, $v ) = each %{ $proc->{in} } ) {
            $rec->{$k} = $v;
        }
        my $prof = $oprof->mod($rec);
        $proc->{in} = $prof;
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

1;
