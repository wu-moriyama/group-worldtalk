package FCC::View::Mypage::DwnlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	my $dwn_intro_chars = $self->{tmpl_loop_params}->{list_loop}->{DWN_INTRO_CHARS} + 0;
	unless($dwn_intro_chars) { $dwn_intro_chars = 100; }
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "dwn_pubdate" && $v > 0) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k =~ /^dwn_(type|loc|status)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /^dwn_(point|num)$/) {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			} elsif($k eq "dwn_intro") {
				my $s = $v;
				$s =~ s/\x0D\x0A|\x0D|\x0A//g;
				$s =~ s/\s+/ /g;
				$s =~ s/^\s+//;
				$s =~ s/\s+$//;
				my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $dwn_intro_chars);
				if($s ne $s2) { $s2 .= "…"; }
				$hash{$k} = CGI::Utils->new()->escapeHtml($s2);
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		push(@list_loop, \%hash);
	}
	$t->param("list_loop" => \@list_loop);
	#カテゴリー検索欄
	my @s_dct_loop;
	for my $ref (@{$context->{dct_list}}) {
		my $h = {};
		while( my($k, $v) = each %{$ref} ) {
			$h->{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		if($res->{params}->{dct_id} == $ref->{dct_id}) {
			$h->{selected} = 'selected="selected"';
		}
		push(@s_dct_loop, $h);
	}
	$t->param("s_dct_loop" => \@s_dct_loop);
	#ページナビゲーション
	my @navi_params = ('hit', 'fetch', 'start', 'end', 'next_num', 'prev_num');
	for my $k (@navi_params) {
		my $v = $res->{$k};
		$t->param($k => $v);
		$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
	}
	$t->param("next_url" => $res->{next_url});
	$t->param("prev_url" => $res->{prev_url});
	#ページナビゲーション
	$t->param("page_loop" => $res->{page_list});
	#検索条件
	while( my($k, $v) = each %{$res->{params}} ) {
		if($k eq "sort_key") {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k =~ /^(limit)$/) {
			$t->param($k => $v);
		} else {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	my $s_dwn_type = $res->{params}->{dwn_type};
	unless( $s_dwn_type ) {
		$s_dwn_type = 0;
	}
	$t->param("s_dwn_type_${s_dwn_type}" => 1);
	#
	$t->param("search_base_url" => $context->{search_base_url});
	#
	$self->print_html($t);
}

1;
