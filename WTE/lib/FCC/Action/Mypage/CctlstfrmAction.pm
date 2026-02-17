package FCC::Action::Mypage::CctlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use CGI::Utils;
use FCC::Class::Member;
use FCC::Class::Cpnact;
use FCC::Class::Lesson;
use FCC::Class::Auto;
use FCC::Class::Dwnsel;
use FCC::Class::Coupon;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
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
	$params->{member_id} = $member_id;
	$params->{sort} = [['cpnact_id', 'DESC']];
	#
	if( ! $params->{limit} || $params->{limit} =~ /[^\d]/ ) {
		$params->{limit} = 100;
	} elsif( $params->{limit} > 100 ) {
		$params->{limit} = 100;
	}
	if( ! $params->{offset} || $params->{offset} =~ /[^\d]/ ) {
		$params->{offset} = 0;
	}
	#クーポン入出金明細情報を検索
	my $occt = new FCC::Class::Cpnact(conf=>$self->{conf}, db=>$self->{db});
	my $res = $occt->get_list($params);
	#レッスン情報とダウンロード情報を付加
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
#	my $odsl = new FCC::Class::Dwnsel(conf=>$self->{conf}, db=>$self->{db});
	for my $act (@{$res->{list}}) {
		if($act->{lsn_id}) {
			my $lsn = $olsn->get($act->{lsn_id});
			unless($lsn) { next; }
			while( my($k, $v) = each %{$lsn} ) {
				$act->{$k} = $v;
			}
#		} elsif($act->{dsl_id}) {
#			my $dsl = $odsl->get($act->{dsl_id});
#			unless($dsl) { next; }
#			while( my($k, $v) = each %{$dsl} ) {
#				$act->{$k} = $v;
#			}
		}
	}
	#最新の会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $member = $omember->get_from_db($member_id);
	#クーポン情報を取得
	if($member->{coupon_id} && $member->{member_coupon}) {
		my $ocoupon = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
		my $coupon = $ocoupon->get($member->{coupon_id});
		$member->{member_coupon_expire} = $coupon->{coupon_expire};
	}
	#ページナビゲーション用リンクの共通パラメータ
	my @url_params = ("m=cctlstfrm");
	while( my($k, $v) = each %{$res->{params}} ) {
		if( ! defined $v ) { next; }
		if($k =~ /^(sort|offset|member_id)$/) { next; }
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
	#月額課金会員かどうか
	my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
	my $auto = $oauto->is_subscription_member($member_id);
	if($auto) {
		$auto->{is_subscription_member} = 1;
	} else {
		$auto = { is_subscription_member => 0 };
	}
	#
	$context->{res} = $res;
	$context->{member} = $member;
	$context->{auto} = $auto;
	return $context;
}


1;
