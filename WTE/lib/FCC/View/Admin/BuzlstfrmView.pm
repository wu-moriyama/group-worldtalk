package FCC::View::Admin::BuzlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		push(@list_loop, \%hash);
	}
	$t->param("list_loop" => \@list_loop);
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
		if($k =~ /^buz_show$/) {
			$t->param("s_${k}_${v}_selected" => 'selected="selected"');
			$t->param("s_${k}_${v}" => 1);
			if($v ne "") {
				$t->param("s_${k}_selected" => 1);
			}
		} elsif($k =~ /^(limit)$/) {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} else {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	#検索対象の会員情報
	if( defined $res->{member} && ref($res->{member}) eq "HASH" ) {
		while( my($k, $v) = each %{$res->{member}} ) {
			$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	#検索対象の講師情報
	if( defined $res->{prof} && ref($res->{prof}) eq "HASH" ) {
		while( my($k, $v) = each %{$res->{prof}} ) {
			$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	# クチコミ登録リンク用（講師で絞り込み中なら prof_id を付与）
	my $buzaddfrm_prof_param = '';
	if ( defined $res->{params}->{prof_id} && $res->{params}->{prof_id} =~ /^\d+$/ ) {
		$buzaddfrm_prof_param = '&amp;prof_id=' . $res->{params}->{prof_id};
	}
	$t->param( buzaddfrm_prof_param => $buzaddfrm_prof_param );
	# 登録完了メッセージ
	$t->param( buzadd_ok => $self->{q}->param('buzadd_ok') ? 1 : 0 );
	#
	$self->print_html($t);
}

1;
