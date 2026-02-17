package FCC::Action::Admin::DwnlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Dwn;
use FCC::Class::Dct;
use FCC::Class::Dwnsel;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = [
		's_dwn_id',
		's_dct_id',
		's_dwn_type',
		's_dwn_loc',
		's_dwn_status',
		'sort_key',
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
	unless( $params->{sort_key} ) {
		$params->{sort_key} = "new";
	}
	if($params->{sort_key} eq "score") {
		$params->{sort} = [ ['dwn_weight', 'DESC'], ['dwn_score', 'DESC'], ['dwn_id', 'DESC'] ];
	} elsif($params->{sort_key} eq "new") {
		$params->{sort} = [ ['dwn_pubdate', 'DESC'], ['dwn_id', 'DESC'] ];
	} else {
		$params->{sort} = [ ['dwn_id', 'DESC'] ];
		$params->{sort_key} = 'id';
	}
	#情報を検索
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $res = $odwn->get_list($params);
	#カテゴリー
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $dct_list = $odct->get_all_list();
	#ページナビゲーション用リンクの共通パラメータ
	my @url_params = ("m=dwnlstfrm");
	while( my($k, $v) = each %{$res->{params}} ) {
		if( ! defined $v ) { next; }
		if($k =~ /^(offset|sort)$/) { next; }
		if($k !~ /^(limit|offset|sort_key)$/) {
			$k = "s_${k}";
		}
		if( ref($v) eq "ARRAY" ) {
			for my $e (@{$v}) {
				my $e_urlenc = CGI::Utils->new()->urlEncode($e);
				push(@url_params, "${k}=${e_urlenc}");
			}
		} else {
			my $v_urlenc = CGI::Utils->new()->urlEncode($v);
			push(@url_params, "${k}=${v_urlenc}");
		}
	}
	#ページナビゲーション（次へ、前へ）
	my $next_url = "";
	my $prev_url = "";
	my $next_num = 0;
	my $prev_num = 0;
	if($res->{params}->{offset} > 0) {
		$prev_url = "$self->{conf}->{CGI_URL}?" . join("&amp;", @url_params);
		my $prev_offset = $res->{params}->{offset} - $res->{params}->{limit};
		if($prev_offset < 0) {
			$prev_offset = 0;
		}
		$prev_url .= "&amp;offset=${prev_offset}";
		$prev_num = $res->{params}->{limit};
	}
	if($res->{hit} > $res->{params}->{offset} + $res->{fetch}) {
		$next_url = "$self->{conf}->{CGI_URL}?" . join("&amp;", @url_params);
		my $next_offset = $res->{params}->{offset} + $res->{params}->{limit};
		if($next_offset > $res->{hit}) {
			$next_offset = $res->{hit};
		}
		$next_url .= "&amp;offset=${next_offset}";
		$next_num = $res->{params}->{limit};
		if($res->{params}->{offset} + $res->{params}->{fetch} + $res->{params}->{limit} > $res->{hit}) {
			$next_num = $res->{hit} - ($res->{params}->{offset} + $res->{params}->{fetch});
		}
	}
	$res->{next_url} = $next_url;
	$res->{prev_url} = $prev_url;
	$res->{next_num} = $next_num;
	$res->{prev_num} = $prev_num;
	#ページナビゲーション（ページ番号リスト）
	my $page_list = [];
	if($res->{hit} <= $res->{params}->{limit}) {
		$page_list->[0] = {
			page => 1,
			current => 1
		};
	} else {
		my $show_page_num = 9;
		my $this_page = int($res->{params}->{offset} / $res->{params}->{limit}) + 1;
		#
		my $min_page = $this_page - int($show_page_num / 2);
		if($min_page < 1) { $min_page = 1; }
		#
		my $max_page = int($res->{hit} / $res->{params}->{limit});
		if( $res->{hit} % $res->{params}->{limit} ) {
			$max_page ++;
		}
		if($max_page > $this_page + int($show_page_num / 2)) {
			$max_page = $this_page + int($show_page_num / 2);
		}
		for( my $p=$min_page; $p<=$max_page; $p++ ) {
			my %hash;
			$hash{page} = $p;
			if($p == $this_page) {
				$hash{current} = 1;
			} else {
				$hash{current} = 0;
			}
			$hash{url} = "$self->{conf}->{CGI_URL}?" . join("&amp;", @url_params);
			my $offset = $res->{params}->{offset} + $res->{params}->{limit} * ($p - $this_page);
			$hash{url} .= "&amp;offset=${offset}";
			push(@{$page_list}, \%hash);
		}
	}
	$res->{page_list} = $page_list;
	#ダウンロード商品（検索条件に商品が指定された場合）
	if( defined $res->{params}->{dwn_id} && $res->{params}->{dwn_id} =~ /^\d+$/ ) {
		$res->{dwn} = $odwn->get($res->{params}->{dwn_id});
	}
	#カテゴリー（検索条件にカテゴリーが指定された場合）
	if( defined $res->{params}->{dct_id} && $res->{params}->{dct_id} =~ /^\d+$/ ) {
		my $dcts = $odct->get();
		$res->{dct} = $dcts->{$res->{params}->{dct_id}};
	}
	#CSVダウンロードURL
	{
		my @url_params = ("m=dwntsvdwn");
		while( my($k, $v) = each %{$res->{params}} ) {
			if( ! defined $v ) { next; }
			if($k =~ /^(offset|limit|sort)$/) { next; }
			my $v_urlenc = CGI::Utils->new()->urlEncode($v);
			push(@url_params, "s_${k}=${v_urlenc}");
		}
		$res->{download_url} = "$self->{conf}->{CGI_URL}?" . join("&amp;", @url_params);
	}
	#販売数
	my $odwnsel = new FCC::Class::Dwnsel(conf=>$self->{conf}, db=>$self->{db});
	for my $dwn (@{$res->{list}}) {
		$dwn->{dwn_num} = $odwnsel->get_dwn_num($dwn->{dwn_id});
	}
	#
	$context->{res} = $res;
	$context->{dct_list} = $dct_list;
	return $context;
}

1;
