package FCC::Action::Seller::CpnlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use CGI::Utils;
use FCC::Class::Coupon;
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#入力値のname属性値のリスト
	my $in_names = [
		's_coupon_id',
		's_coupon_code',
		's_coupon_available',
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
	$params->{seller_id} = $seller_id;
	$params->{sort} = [ ['coupon_id', 'DESC'] ];
	#クーポン情報を検索
	my $ocpn = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
	my $res = $ocpn->get_list($params);
	#ページナビゲーション用リンクの共通パラメータ
	my @url_params = ("m=cpnlstfrm");
	while( my($k, $v) = each %{$res->{params}} ) {
		if( ! defined $v ) { next; }
		if($k =~ /^(offset|sort)$/) { next; }
		if($k !~ /^(limit|offset)$/) {
			$k = "s_${k}";
		}
		my $v_urlenc = CGI::Utils->new()->urlEncode($v);
		push(@url_params, "${k}=${v_urlenc}");
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
	#FCC::Class::Sellerのインスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#代理店情報を取得
	if($res->{fetch} > 0) {
		my $seller_id_list = [];
		for my $ref (@{$res->{list}}) {
			my $sel = $oseller->get($ref->{seller_id});
			unless($sel) { next; }
			while( my($k, $v) = each %{$sel} ) {
				$ref->{$k} = $v;
			}
		}
	}
	#
	$context->{res} = $res;
	return $context;
}


1;
