package FCC::Action::Admin::LsnlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Prof;
use FCC::Class::Course;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #入力値のname属性値のリスト
    my $in_names = [ 's_lsn_id', 's_member_id', 's_prof_id', 's_course_id', 's_lsn_stime_s', 's_lsn_stime_e', 's_lsn_status', 'limit', 'offset' ];

    #入力値を取得
    my $in     = $self->get_input_data($in_names);
    my $params = {};
    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v || $v eq "" ) { next; }
        $k =~ s/^s_//;
        $params->{$k} = $v;
    }
    $params->{sort} = [ [ 'lsn_stime', 'DESC' ] ];

    #レッスン情報を検索
    my $olsn = new FCC::Class::Lesson( conf => $self->{conf}, db => $self->{db} );
    my $res  = $olsn->get_list($params);

    #ページナビゲーション用リンクの共通パラメータ
    my @url_params = ("m=lsnlstfrm");
    while ( my ( $k, $v ) = each %{ $res->{params} } ) {
        if ( !defined $v ) { next; }
        if ( $k =~ /^(offset|sort)$/ ) { next; }
        if ( $k !~ /^(limit|offset)$/ ) {
            $k = "s_${k}";
        }
        my $v_urlenc = CGI::Utils->new()->urlEncode($v);
        push( @url_params, "${k}=${v_urlenc}" );
    }

    #ページナビゲーション（次へ、前へ）
    my $next_url = "";
    my $prev_url = "";
    my $next_num = 0;
    my $prev_num = 0;
    if ( $res->{params}->{offset} > 0 ) {
        $prev_url = "$self->{conf}->{CGI_URL}?" . join( "&amp;", @url_params );
        my $prev_offset = $res->{params}->{offset} - $res->{params}->{limit};
        if ( $prev_offset < 0 ) {
            $prev_offset = 0;
        }
        $prev_url .= "&amp;offset=${prev_offset}";
        $prev_num = $res->{params}->{limit};
    }
    if ( $res->{hit} > $res->{params}->{offset} + $res->{fetch} ) {
        $next_url = "$self->{conf}->{CGI_URL}?" . join( "&amp;", @url_params );
        my $next_offset = $res->{params}->{offset} + $res->{params}->{limit};
        if ( $next_offset > $res->{hit} ) {
            $next_offset = $res->{hit};
        }
        $next_url .= "&amp;offset=${next_offset}";
        $next_num = $res->{params}->{limit};
        if ( $res->{params}->{offset} + $res->{params}->{fetch} + $res->{params}->{limit} > $res->{hit} ) {
            $next_num = $res->{hit} - ( $res->{params}->{offset} + $res->{params}->{fetch} );
        }
    }
    $res->{next_url} = $next_url;
    $res->{prev_url} = $prev_url;
    $res->{next_num} = $next_num;
    $res->{prev_num} = $prev_num;

    #ページナビゲーション（ページ番号リスト）
    my $page_list = [];
    if ( $res->{hit} <= $res->{params}->{limit} ) {
        $page_list->[0] = {
            page    => 1,
            current => 1
        };
    }
    else {
        my $show_page_num = 9;
        my $this_page     = int( $res->{params}->{offset} / $res->{params}->{limit} ) + 1;
        #
        my $min_page = $this_page - int( $show_page_num / 2 );
        if ( $min_page < 1 ) { $min_page = 1; }
        #
        my $max_page = int( $res->{hit} / $res->{params}->{limit} );
        if ( $res->{hit} % $res->{params}->{limit} ) {
            $max_page++;
        }
        if ( $max_page > $this_page + int( $show_page_num / 2 ) ) {
            $max_page = $this_page + int( $show_page_num / 2 );
        }
        for ( my $p = $min_page ; $p <= $max_page ; $p++ ) {
            my %hash;
            $hash{page} = $p;
            if ( $p == $this_page ) {
                $hash{current} = 1;
            }
            else {
                $hash{current} = 0;
            }
            $hash{url} = "$self->{conf}->{CGI_URL}?" . join( "&amp;", @url_params );
            my $offset = $res->{params}->{offset} + $res->{params}->{limit} * ( $p - $this_page );
            $hash{url} .= "&amp;offset=${offset}";
            push( @{$page_list}, \%hash );
        }
    }
    $res->{page_list} = $page_list;

    #会員情報を取得
    my $omember = new FCC::Class::Member( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $members = {};
    if ( $res->{fetch} > 0 ) {
        my $member_id_list = [];
        for my $ref ( @{ $res->{list} } ) {
            my $member = $members->{ $ref->{member_id} };
            unless ($member) {
                $member = $omember->get( $ref->{member_id} );
                if ($member) {
                    $members->{ $ref->{member_id} } = $member;
                }
            }
            unless ($member) { next; }
            while ( my ( $k, $v ) = each %{$member} ) {
                $ref->{$k} = $v;
            }
        }
    }

    #会員情報（検索条件に会員識別IDが指定された場合）
    if ( defined $res->{params}->{member_id} && $res->{params}->{member_id} =~ /^\d+$/ ) {
        my $omember = new FCC::Class::Member( conf => $self->{conf}, db => $self->{db} );
        $res->{member} = $omember->get_from_db( $res->{params}->{member_id} );
    }

    #講師情報（検索条件に講師識別IDが指定された場合）
    if ( defined $res->{params}->{prof_id} && $res->{params}->{prof_id} =~ /^\d+$/ ) {
        my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db} );
        $res->{prof} = $oprof->get_from_db( $res->{params}->{prof_id} );
    }

    #授業情報（検索条件に授業識別IDが指定された場合）
    if ( defined $res->{params}->{course_id} && $res->{params}->{course_id} =~ /^\d+$/ ) {
        my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
        $res->{course} = $ocourse->get( $res->{params}->{course_id} );
    }

    #CSVダウンロードURL
    {
        my @url_params = ("m=lsntsvdwn");
        while ( my ( $k, $v ) = each %{ $res->{params} } ) {
            if ( !defined $v ) { next; }
            if ( $k =~ /^(offset|limit|sort)$/ ) { next; }
            my $v_urlenc = CGI::Utils->new()->urlEncode($v);
            push( @url_params, "s_${k}=${v_urlenc}" );
        }
        $res->{download_url} = "$self->{conf}->{CGI_URL}?" . join( "&amp;", @url_params );
    }
    #
    $context->{res} = $res;
    return $context;
}

1;
