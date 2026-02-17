package FCC::View::Mypage::LsnlstfrmView;
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
	my $lsn_prof_repo_note_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_PROF_REPO_NOTE_CHARS} + 0;
	my $lsn_member_repo_note_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_MEMBER_REPO_NOTE_CHARS} + 0;
	my $lsn_review_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_REVIEW_CHARS} + 0;
	my $chars = {
		lsn_prof_repo_note   => $lsn_prof_repo_note_chars ? $lsn_prof_repo_note_chars : 100,
		lsn_member_repo_note => $lsn_member_repo_note_chars ? $lsn_member_repo_note_chars : 100,
		lsn_review           => $lsn_review_chars ? $lsn_review_chars : 100
	};
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^(prof_cdate|prof_mdate)$/) {
				if($v) {
					my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
					for( my $i=0; $i<=9; $i++ ) {
						$hash{"${k}_${i}"} = $tm[$i];
					}
				}
			} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /^lsn_(cancelable|prof_repo|member_repo|member_repo_rating|status)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/) {
				my $tmp = CGI::Utils->new()->escapeHtml($v);
				$tmp =~ s/\n/<br \/>/g;
				$hash{$k} = $tmp;
			} elsif($k =~ /^lsn_(prof_repo_note|member_repo_note|review)$/) {
				my $len = $chars->{$k};
				my $v2 = FCC::Class::String::Conv->new($v, "utf8")->truncate_chars(0, $len);
				if($v ne $v2) { $v2 .= "…"; }
				$v2 = CGI::Utils->new()->escapeHtml($v2);
				$v2 =~ s/\n/<br \/>/g;
				$hash{$k} = $v2;
			} elsif($k =~ /^lsn_(cancel_reason)$/) {
				my $tmp = CGI::Utils->new()->escapeHtml($v);
				$tmp =~ s/\n/<br \/>/g;
				$hash{$k} = $tmp;
			} elsif($k eq "prof_rank") {
				my $title = $self->{conf}->{"prof_rank${v}_title"};
				$hash{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
			} elsif($k =~ /_(fee|price)$/) {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
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
	#
	$self->print_html($t);
}

1;
