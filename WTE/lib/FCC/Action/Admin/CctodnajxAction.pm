package FCC::Action::Admin::CctodnajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Ccate;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #入力値のname属性値のリスト
    my $in_names = [ "ccate_id", ];

    #入力値を取得
    my $in     = $self->get_input_data($in_names);
    my $params = {};
    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v || $v eq "" ) { next; }
        $params->{$k} = $v;
    }

    #入力値チェック
    my $occate =
      new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    my @errs = $occate->input_check( $in_names, $params );

    #エラーハンドリング

    if (@errs) {
        $context->{fatalerrs} = [ $errs[0]->[1] ];
        return $context;
    }
    else {
        my $cate = $occate->down( $params->{ccate_id} );
        $context->{res} = $cate;
        return $context;
    }
}

1;
