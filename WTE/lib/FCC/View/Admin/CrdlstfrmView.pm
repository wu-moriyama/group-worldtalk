package FCC::View::Admin::CrdlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
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
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^crd_(price|point)$/) {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			} elsif($k =~ /^crd_success$/) {
				$hash{"${k}_${v}"} = 1;
			}
		}
		if($ref->{pln_id} && $context->{plns}->{$ref->{pln_id}}) {
			my $pln_title = $context->{plns}->{$ref->{pln_id}}->{pln_title};
			$hash{pln_title} = CGI::Utils->new()->escapeHtml($pln_title);
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
		if($k =~ /^crd_success$/) {
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
	#プラン
	my @s_pln_id_loop;
	my $selected_pln_title = "";
	for my $pln (@{$context->{pln_list}}) {
		my $hash = {};
		while( my($k, $v) = each %{$pln} ) {
			$hash->{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		if($res->{params}->{pln_id} eq $pln->{pln_id}) {
			$hash->{selected} = 'selected="selected"';
			$selected_pln_title = $pln->{pln_title};
		}
		push(@s_pln_id_loop, $hash);
	}
	$t->param("s_pln_id_loop" => \@s_pln_id_loop);
	$t->param("selected_pln_title" => CGI::Utils->new()->escapeHtml($selected_pln_title));
	#検索対象の会員情報
	if( defined $res->{member} && ref($res->{member}) eq "HASH" ) {
		while( my($k, $v) = each %{$res->{member}} ) {
			$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	#CSVダウンロードURL
	$t->param("download_url" => $res->{download_url});
	#
	$self->print_html($t);
}

1;
