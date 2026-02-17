package FCC::Action::Prof::CoulstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use CGI::Utils;
use FCC::Class::Course;
use FCC::Class::Ccate;

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $prof_id = $self->{session}->{data}->{prof}->{prof_id};


	#入力値のname属性値のリスト
	my $in_names = [
		'limit',
		'offset'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$params->{$k} = $v;
	}
	$params->{prof_id} = $prof_id;
    $params->{sort} = [ [ 'course_id', 'DESC' ] ];

	if( ! $params->{limit} || $params->{limit} =~ /[^\d]/ ) {
		$params->{limit} = 20;
	} elsif( $params->{limit} > 20 ) {
		$params->{limit} = 20;
	}
	if( ! $params->{offset} || $params->{offset} =~ /[^\d]/ ) {
		$params->{offset} = 0;
	}

    #情報を検索
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $res     = $ocourse->get_list($params);

    #ページナビゲーション用リンクの共通パラメータ
    my @url_params = ("m=coulstfrm");
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
        my $this_page =
          int( $res->{params}->{offset} / $res->{params}->{limit} ) + 1;
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

    #カテゴリー取得
    my $occate = new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    $res->{ccate_list} = $occate->get_children( { ccate_status => 1 } );
    $res->{ccates}     = $occate->get_all();

    $context->{res} = $res;
    return $context;
}

1;
