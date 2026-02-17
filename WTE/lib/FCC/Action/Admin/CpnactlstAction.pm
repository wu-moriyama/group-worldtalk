package FCC::Action::Admin::CpnactlstAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Cpnact;
use FCC::Class::Member;
use FCC::Class::Lesson;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = ['s_member_id', 's_cdate1', 's_cdate2', 'limit', 'offset'];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		if($k eq "cdate1") {
			if($v =~ /^\d{4}\-\d{2}\-\d{2}$/) {
				my $iso = "${v} 00:00:00";
				$params->{"cpnact_cdate1"} = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz}, iso=>$iso)->epoch();
			} else {
				next;
			}
		} elsif($k eq "cdate2") {
			if($v =~ /^\d{4}\-\d{2}\-\d{2}$/) {
				my $iso = "${v} 23:59:59";
				$params->{"cpnact_cdate2"}  = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz}, iso=>$iso)->epoch();
			} else {
				next;
			}
		}
		$params->{$k} = $v;
	}
	$params->{sort} = [ ['cpnact_id', 'DESC'] ];
	#入出金明細情報を検索
	my $ocpnact = new FCC::Class::Cpnact(conf=>$self->{conf}, db=>$self->{db});
	my $res = $ocpnact->get_list($params);
	#レッスン情報を付加
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	for my $act (@{$res->{list}}) {
		unless($act->{lsn_id}) { next; }
		my $lsn = $olsn->get($act->{lsn_id});
		unless($lsn) { next; }
		while( my($k, $v) = each %{$lsn} ) {
			$act->{$k} = $v;
		}
	}
	#
	if($params->{cpnact_cdate1}) {
		$res->{params}->{cdate1} = $params->{cdate1};
	}
	if($params->{cpnact_cdate2}) {
		$res->{params}->{cdate2} = $params->{cdate2};
	}
	#ページナビゲーション用リンクの共通パラメータ
	my @url_params = ("m=cpnactlst");
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
	#会員情報（検索条件に会員識別IDが指定された場合）
	if( defined $res->{params}->{member_id} && $res->{params}->{member_id} =~ /^\d+$/ ) {
		my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		$res->{member} = $omember->get_from_db($res->{params}->{member_id});
	}
	#
	$context->{res} = $res;
	return $context;
}


1;
