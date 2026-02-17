package FCC::Action::Admin::CoutsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Course;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #入力値のname属性値のリスト
    my $in_names = [ 's_course_id', 's_prof_id', 's_course_status', 's_course_ccate_id_1', 's_course_ccate_id_2', 'limit', 'offset' ];

    #入力値を取得
    my $in     = $self->get_input_data($in_names);
    my $params = {};
    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v || $v eq "" ) { next; }
        $k =~ s/^s_//;
        $params->{$k} = $v;
    }
    $params->{sort}       = [ [ 'course_id', 'DESC' ] ];
    $params->{charcode}   = "sjis";
    $params->{returncode} = "\x0a";

    #CSVを生成
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $res     = $ocourse->get_csv($params);
    #
    $context->{res} = $res;
    return $context;
}

1;
