package FCC::View::Prof::CoudelfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #テンプレートのロード
    my $t = $self->load_template();
    $t->param( "pkey" => $context->{proc}->{pkey} );

    #情報
    my $course = $context->{proc}->{course};
    while ( my ( $k, $v ) = each %{$course} ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /^course_(cdate|mdate)$/ ) {
            my @tm = FCC::Class::Date::Utils->new( time => $v, tz => $self->{conf}->{tz} )->get(1);
            for ( my $i = 0 ; $i <= 9 ; $i++ ) {
                $t->param( "${k}_${i}" => $tm[$i] );
            }
        }
        elsif ( $k =~ /^course_(status)$/ ) {
            $t->param( "${k}_${v}" => 1 );
        }
        elsif ( $k =~ /^course_(intro|memo)$/ ) {
            my $tmp = CGI::Utils->new()->escapeHtml($v);
            $tmp =~ s/\n/<br>/g;
            $t->param( $k => $tmp );
        }
        elsif ( $k =~ /^course_(fee)$/ ) {
            $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
        }
    }

    #検索対象のカテゴリー
    my $ccate_id_1 = $course->{course_ccate_id_1};
    if ($ccate_id_1) {
        my $ccate1 = $context->{ccates}->{$ccate_id_1};
        if ($ccate1) {
            $t->param( "ccate_name_1" => CGI::Utils->new()->escapeHtml( $ccate1->{ccate_name} ) );
        }
    }

    my $ccate_id_2 = $course->{course_ccate_id_2};
    if ($ccate_id_2) {
        my $ccate2 = $context->{ccates}->{$ccate_id_2};
        if ($ccate2) {
            $t->param( "ccate_name_2" => CGI::Utils->new()->escapeHtml( $ccate2->{ccate_name} ) );
        }
    }

    #プロセスエラー
    if ( defined $context->{proc}->{errs} && @{ $context->{proc}->{errs} } ) {
        my $errs = "<ul>";
        for my $e ( @{ $context->{proc}->{errs} } ) {
            $t->param( "$e->[0]_err" => "err" );
            $errs .= "<li>$e->[1]</li>";
        }
        $errs .= "</ul>";
        $t->param( 'errs' => $errs );
    }
    #
    $self->print_html($t);
}

1;
