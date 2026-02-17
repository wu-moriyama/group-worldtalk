package FCC::View::Mypage::ParentView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	#お知らせ
	my @ann_loop;
	for my $ann (@{$context->{ann_list}}) {
		my %h;
		while( my($k, $v) = each %{$ann} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "ann_cdate") {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$h{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k eq "ann_content") {
				$v = CGI::Utils->new()->escapeHtml($v);
				$v =~ s/(https?\:\/\/[0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?\;\,]+)/<a href=\"$1\" target=\"_blank\">$1<\/a\>/g;
				$v =~ s/\n/<br \/>/g;
				$h{$k} = $v;
			}
		}
		push(@ann_loop, \%h);
	}
	$t->param("ann_loop" => \@ann_loop);
	#動画一覧
	my $epoch = time;
	my $dwn_1_intro_chars = $self->{tmpl_loop_params}->{dwn_1_loop}->{DWN_INTRO_CHARS} + 0;
	unless($dwn_1_intro_chars) { $dwn_1_intro_chars = 100; }
	my @dwn_1_loop;
	for my $dwn (@{$context->{dwn_1_list}}) {
		my %hash;
		while( my($k, $v) = each %{$dwn} ) {
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
				my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $dwn_1_intro_chars);
				if($s ne $s2) { $s2 .= "…"; }
				$hash{$k} = CGI::Utils->new()->escapeHtml($s2);
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		push(@dwn_1_loop, \%hash);
	}
	$t->param("dwn_1_loop" => \@dwn_1_loop);
	#PDF一覧
	my $dwn_2_intro_chars = $self->{tmpl_loop_params}->{dwn_2_loop}->{DWN_INTRO_CHARS} + 0;
	unless($dwn_2_intro_chars) { $dwn_2_intro_chars = 100; }
	my @dwn_2_loop;
	for my $dwn (@{$context->{dwn_2_list}}) {
		my %hash;
		while( my($k, $v) = each %{$dwn} ) {
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
				my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $dwn_2_intro_chars);
				if($s ne $s2) { $s2 .= "…"; }
				$hash{$k} = CGI::Utils->new()->escapeHtml($s2);
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		push(@dwn_2_loop, \%hash);
	}
	$t->param("dwn_2_loop" => \@dwn_2_loop);
	#現在レッスン中のレッスン情報
	while( my($k, $v) = each %{$context->{lsn}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^lsn_(cancel|cancelable|prof_repo|member_repo|member_repo_rating|pay_type|status)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^lsn_(cancel_reason|prof_repo_note|member_repo_note)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k =~ /_(fee|price)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	#最新の会員情報
	while( my($k, $v) = each %{$context->{member}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^member_(point|coupon)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	#進捗報告
	my $prep_num = scalar @{$context->{prep_list}};
	$t->param("prep_num" => $prep_num);
	my @prep_loop;
	for my $prep (@{$context->{prep_list}}) {
		my %h;
		while( my($k, $v) = each %{$prep} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "prep_content") {
				$v = CGI::Utils->new()->escapeHtml($v);
				$v =~ s/(https?\:\/\/[0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?\;\,]+)/<a href=\"$1\" target=\"_blank\">$1<\/a\>/g;
				$v =~ s/\n/<br \/>/g;
				$h{$k} = $v;
			}
		}
		push(@prep_loop, \%h);
	}
	$t->param("prep_loop" => \@prep_loop);
	#レッスン一覧
	my $lsn_prof_repo_note_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_PROF_REPO_NOTE_CHARS} + 0;
	my $lsn_member_repo_note_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_MEMBER_REPO_NOTE_CHARS} + 0;
	my $lsn_review_chars = $self->{tmpl_loop_params}->{list_loop}->{LSN_REVIEW_CHARS} + 0;
	my $chars = {
		lsn_prof_repo_note   => $lsn_prof_repo_note_chars ? $lsn_prof_repo_note_chars : 100,
		lsn_member_repo_note => $lsn_member_repo_note_chars ? $lsn_member_repo_note_chars : 100,
		lsn_review           => $lsn_review_chars ? $lsn_review_chars : 100
	};
	my @lesson_loop;
	for my $ref (@{$context->{lesson_list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^(prof_cdate|prof_mdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
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
		push(@lesson_loop, \%hash);
	}
	$t->param("lesson_loop" => \@lesson_loop);
	#現在の保持ポイントと有効期限
	while( my($k, $v) = each %{$context->{member}} ) {
		if($k =~ /^member_(point|coupon)$/) {
			$t->param($k => $v);
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} elsif($k =~ /^member_(point|coupon)_expire$/) {
			my($y, $m, $d) = split(/\-/, $v);
			$m += 0;
			$d += 0;
			$t->param("${k}_y" => $y);
			$t->param("${k}_m" => $m);
			$t->param("${k}_d" => $d);
		}
	}
	#
	while( my($k, $v) = each %{$context->{auto}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^auto_(point|price)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	#
	$self->print_html($t);
}

1;
