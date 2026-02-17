package FCC::Action::Mypage::PrflstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use CGI::Utils;
use FCC::Class::Prof;
use FCC::Class::Fav;

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    #入力値のname属性値のリスト
    my $in_names = [ 's_prof_handle', 's_prof_rank', 's_prof_fulltext', 's_prof_gender', 's_prof_country', 's_prof_residence', 's_prof_reco', 's_prof_character', 's_prof_interest', 'sort_key', 'limit', 'offset' ];

    #入力値を取得
    my $in     = $self->get_input_data( $in_names, [ "s_prof_character", "s_prof_interest" ] );
    my $params = {};
    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v || $v eq "" ) { next; }
        $k =~ s/^s_//;
        $params->{$k} = $v;
    }
    $params->{prof_status} = 1;
    #
    if ( !$params->{limit} || $params->{limit} =~ /[^\d]/ ) {
        $params->{limit} = 20;
    }
    elsif ( $params->{limit} > 100 ) {
        $params->{limit} = 100;
    }
    if ( !$params->{offset} || $params->{offset} =~ /[^\d]/ ) {
        $params->{offset} = 0;
    }
    #
    if ( $params->{sort_key} eq "new" ) {
        $params->{sort}     = [ [ 'prof_id', 'DESC' ] ];
        $params->{sort_key} = 'new';
    }
    elsif ( $params->{sort_key} eq "rank" ) {
        $params->{sort} = [ [ 'prof_rank', 'ASC' ], [ 'prof_order_weight', 'DESC' ], [ 'prof_score', 'DESC' ], [ 'prof_id', 'DESC' ] ];
    }
    else {
        $params->{sort}     = [ [ 'prof_order_weight', 'DESC' ], [ 'prof_score', 'DESC' ], [ 'prof_id', 'DESC' ] ];
        $params->{sort_key} = "score";
    }

    #講師情報を検索
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $res   = $oprof->get_list($params);

    #お気に入り
    my $ofav           = new FCC::Class::Fav( conf => $self->{conf}, db => $self->{db} );
    my $fav_search_res = $ofav->get_list( { member_id => $member_id, offset => 0, limit => $self->{conf}->{member_fav_limit} } );
    my $favs           = {};
    for my $fav ( @{ $fav_search_res->{list} } ) {
        $favs->{ $fav->{prof_id} } = $fav;
    }
    for my $prof ( @{ $res->{list} } ) {
        if ( $favs->{ $prof->{prof_id} } ) {
            $prof->{is_fav} = 1;
        }
        else {
            $prof->{is_fav} = 0;
        }
    }

    #ページナビゲーション用リンクの共通パラメータ
    my @url_params = ("m=prflstfrm");
    while ( my ( $k, $v ) = each %{ $res->{params} } ) {
        if ( !defined $v ) { next; }
        if ( $k =~ /^(offset|sort|prof_status)$/ ) { next; }
        if ( $k !~ /^(limit|offset|sort_key)$/ ) {
            $k = "s_${k}";
        }
        if ( ref($v) eq "ARRAY" ) {
            for my $e ( @{$v} ) {
                my $e_urlenc = CGI::Utils->new()->urlEncode($e);
                push( @url_params, "${k}=${e_urlenc}" );
            }
        }
        else {
            my $v_urlenc = CGI::Utils->new()->urlEncode($v);
            push( @url_params, "${k}=${v_urlenc}" );
        }
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

    #国選択肢リスト
    my $country_list = $oprof->get_prof_country_list();
    my $country_hash = $oprof->get_prof_country_hash();
    #
    my @base_url_params = ("m=prflstfrm");
    while ( my ( $k, $v ) = each %{ $res->{params} } ) {
        if ( !defined $v ) { next; }
        if ( $k =~ /^(sort_key|sort|prof_status)$/ ) { next; }
        if ( $k !~ /^(limit|offset)$/ ) {
            $k = "s_${k}";
        }
        if ( ref($v) eq "ARRAY" ) {
            for my $e ( @{$v} ) {
                my $e_urlenc = CGI::Utils->new()->urlEncode($e);
                push( @base_url_params, "${k}=${e_urlenc}" );
            }
        }
        else {
            my $v_urlenc = CGI::Utils->new()->urlEncode($v);
            push( @base_url_params, "${k}=${v_urlenc}" );
        }
    }
    my $search_base_url = "$self->{conf}->{CGI_URL}?" . join( "&amp;", @base_url_params );
    #
    $context->{res}             = $res;
    $context->{country_list}    = $country_list;
    $context->{country_hash}    = $country_hash;
    $context->{search_base_url} = $search_base_url;
    return $context;
}

1;
