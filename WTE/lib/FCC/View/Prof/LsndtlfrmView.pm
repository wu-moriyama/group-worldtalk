package FCC::View::Prof::LsndtlfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
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
	$t->param("pkey" => $context->{proc}->{pkey});
	#レッスン・会員情報
	while( my($k, $v) = each %{$context->{lsn}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^(prof_cdate|prof_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^lsn_(cancel|cancelable|prof_repo|member_repo|member_repo_rating|pay_type|status)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^member_(gender)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k =~ /^lsn_(cancel_reason|prof_repo_note|member_repo_note)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k =~ /^member_(intro|comment)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k eq "prof_rank") {
			my $title = $self->{conf}->{"prof_rank${v}_title"};
			$t->param("${k}_title" => CGI::Utils->new()->escapeHtml($title));
		} elsif($k =~ /_(fee|price)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	#会員の目的/希望/興味/レベル・属性
	for my $k ('member_purpose', 'member_demand', 'member_interest', 'member_level') {
		my $v = $context->{lsn}->{$k} + 0;
		my $bin = unpack("B32", pack("N", $v));
		my @bits = split(//, $bin);
		my @loop;
		for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
			my $title = $self->{conf}->{"${k}${id}_title"};
			my $checked = "";
			if($title eq "") { next; }
			unless( $bits[-$id] ) { next; }
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title)
			};
			push(@loop, $h);
		}
		$t->param("${k}_loop" => \@loop);
	}
	#メッセージ
	my $msg_num = scalar @{$context->{msg_list}};
	$t->param("msg_num" => $msg_num);
	my @msg_loop;
	for my $msg (@{$context->{msg_list}}) {
		my %h;
		while( my($k, $v) = each %{$msg} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "msg_direction") {
				$h{"${k}_${v}"} = 1;
			} elsif($k eq "msg_content") {
				my $tmp = CGI::Utils->new()->escapeHtml($v);
				$tmp =~ s/\n/<br \/>/g;
				$tmp =~ s/(https?\:\/\/[0-9a-zA-Z\#\%\&\=\~\+\-\?\.\_\,\@\$\:\/\;]+)/<a href=\"$1\" target=\"_blank\">$1<\/a>/g;
				$h{$k} = $tmp;
			}
		}
		push(@msg_loop, \%h);
	}
	$t->param("msg_loop" => \@msg_loop);
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
	#
	$self->print_html($t);
}

1;
