package FCC::Action::Admin::PrftsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Prof;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #入力値のname属性値のリスト
    my $in_names = [ 's_prof_id', 's_prof_handle', 's_prof_email', 's_prof_rank', 's_prof_intro', 's_prof_gender', 's_prof_country', 's_prof_residence', 's_prof_reco', 's_prof_character', 's_prof_interest', 's_prof_status', 'sort_key' ];

    #入力値を取得
    my $in     = $self->get_input_data( $in_names, [ "s_prof_character", "s_prof_interest" ] );
    my $params = {};
    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v || $v eq "" ) { next; }
        $k =~ s/^s_//;
        $params->{$k} = $v;
    }
    if ( $params->{sort_key} eq "score" ) {
        $params->{sort} = [ [ 'prof_order_weight', 'DESC' ], [ 'prof_score', 'DESC' ], [ 'prof_id', 'DESC' ] ];
    }
    else {
        $params->{sort}     = [ [ 'prof_id', 'DESC' ] ];
        $params->{sort_key} = 'id';
    }
    $params->{charcode}   = "sjis";
    $params->{returncode} = "\x0a";

    #CSVを生成
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db} );
    my $res   = $oprof->get_csv($params);
    #
    $context->{res} = $res;
    return $context;
}

1;
