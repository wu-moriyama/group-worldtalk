package FCC::View::Admin::LsnmodfrmView;
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
	$t->param("pkey" => $context->{proc}->{pkey});
	#レッスン・講師情報
	while( my($k, $v) = each %{$context->{lsn}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^lsn_(cdate|cancel_date|prof_repo_date|member_repo_date|status_date|charged_date)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^lsn_(cancel|cancelable|prof_repo|member_repo|member_repo_rating|pay_type|pdm_status)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k eq "lsn_status") {
			$t->param("${k}_${v}" => 1);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k =~ /^lsn_(cancel_reason|prof_repo_note|member_repo_note)$/) {
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
			} elsif($k eq "msg_cdate") {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$h{"${k}_${i}"} = $tm[$i];
				}
			}
		}
		$h{member_caption} = CGI::Utils->new()->escapeHtml($self->{conf}->{member_caption});
		$h{prof_caption}   = CGI::Utils->new()->escapeHtml($self->{conf}->{prof_caption});
		push(@msg_loop, \%h);
	}
	$t->param("msg_loop" => \@msg_loop);
	#
	$self->print_html($t);
}

1;
