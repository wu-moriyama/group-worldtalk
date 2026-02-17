package FCC::Action::Prof::LsnlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use CGI::Utils;
use FCC::Class::Lesson;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
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
	$params->{sort} = [['lsn_stime', 'DESC']];
	#
	if( ! $params->{limit} || $params->{limit} =~ /[^\d]/ ) {
		$params->{limit} = 100;
	} elsif( $params->{limit} > 100 ) {
		$params->{limit} = 100;
	}
	if( ! $params->{offset} || $params->{offset} =~ /[^\d]/ ) {
		$params->{offset} = 0;
	}
	#レッスン情報を検索
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res = $olsn->get_list($params);
	#会員情報を付加
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $members = {};
	for my $lsn (@{$res->{list}}) {
		my $member_id = $lsn->{member_id};
		my $m = $members->{$member_id} ? $members->{$member_id} : $omember->get($member_id);
		unless($m) { next; }
		while( my($k, $v) = each %{$m} ) {
			$lsn->{$k} = $v;
		}
	}

	# ============================
	# グループレッスンまとめ処理
	# ============================
	my %groups;

	for my $lsn (@{$res->{list}}) {

		my $group_key = join(
			"_",
			$lsn->{prof_id},
			$lsn->{lsn_stime},
			$lsn->{lsn_etime},
			$lsn->{course_id},
		);

		push @{$groups{$group_key}}, $lsn;
	}

	my @group_list;

	for my $key (sort {
			$groups{$b}[0]->{lsn_stime} cmp $groups{$a}[0]->{lsn_stime}
		} keys %groups) {

		my $items = $groups{$key};
		my $base  = $items->[0];

		my %row = %{$base};

		$row{is_group}      = (@$items > 1 ? 1 : 0);
		$row{group_count}   = scalar(@$items);
		$row{group_members} = $items;
		$row{group_key}     = $key;

		push @group_list, \%row;
	}

	# 一覧用に差し替え
	$res->{list}  = \@group_list;
	$res->{fetch} = scalar(@group_list);
	$res->{hit}   = scalar(@group_list);



	#ページナビゲーション用リンクの共通パラメータ
	my @url_params = ("m=lsnlstfrm");
	while( my($k, $v) = each %{$res->{params}} ) {
		if( ! defined $v ) { next; }
		if($k =~ /^(offset|sort|prof_id)$/) { next; }
		if($k !~ /^(limit|offset)$/) {
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
	#
	$context->{res} = $res;
	return $context;
}


1;
