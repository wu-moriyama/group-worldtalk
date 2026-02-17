package FCC::View::Mypage::_SuperView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::_SuperView);
use CGI::Utils;
use HTML::Template;
use File::Read;
use FCC::Class::String::Conv;

sub error {
	my($self, $errs) = @_;
	my @list = @{$errs};
	my $n = scalar @list;
	my $msg;
	if($n == 1) {
		$msg = $list[0];
	} else {
		$msg .= "<ul>";
		for my $s (@list) {
			$msg .= "<li>${s}</li>";
		}
		$msg .= "</ul>";
	}
	my $dpath = $self->{conf}->{BASE_DIR} . "/template/" . $self->{conf}->{FCC_SELECTOR};
	my $fpath = $dpath . "/error.html";
	my $member = $self->{session}->{data}->{member};
	if($member && $member->{member_lang} == 2) {
		my $fpath_en = $dpath . "en/error.html";
		if(-e $fpath_en) {
			$fpath = $fpath_en;
		}
	}
	my $t = $self->load_template($fpath);
	$t->param('error' => $msg);
	$self->print_html($t);
}

sub load_template {
	my($self, $f, $tmpl, $lang) = @_;
	my $seller_id = 0;
	my $member = $self->{session}->{data}->{member};
	if($member) {
		$seller_id = $member->{seller_id};
	}
	if( ! $f && ! $tmpl) {
		if($self =~ /^FCC::View::([\w\:]+)/) {
			my $v = $1;
			$v =~ s/\:\:/\//g;
			$v =~ s/View$//;
			if($v =~ /\/Default$/) {
				my $m = $self->{q}->param('m');
				if($m) {
					if($m =~ /[^a-zA-Z0-9]/) {
						$self->error404();
					} else {
						$m = ucfirst $m;
						$v =~ s/\/Default$/\/${m}/;
					}
				} else {
					$v =~ s/\/Default$/\/Index/;
				}
			}
			$f = "$self->{conf}->{BASE_DIR}/template/${v}.html";
			if($seller_id) {
				my $f2 = $f;
				$f2 =~ s/\/([a-zA-Z0-9]+\.html)$/\/${seller_id}\/$1/;
				if(-e $f2) {
					$f = $f2;
				}
			}
		} else {
			$self->error404();
		}
	}
	#テンプレートファイルをロード
	if( ! $tmpl ) {
		unless( -e $f ) {
			$self->error404();
		}

		if($lang eq "2" || ($member && $member->{member_lang} == 2)) {
			my $f_en = $f;
			$f_en =~ s/\/Mypage\//\/Mypageen\//;
			if(-e $f_en) {
				$f = $f_en;
			}
		}

		$tmpl = File::Read::read_file($f);
	}
	#HTML::Templateオブジェクトを生成
	my $params = {};
	my $filter = sub {
		my $text_ref = shift;
		my $regexpfilter = sub {
			my($name,$paramstr) = @_;
			my @ary = split(/\s+/, $paramstr);
			for my $pair (@ary) {
				if( my($k, $v) = $pair =~ /^([A-Z\_]+)\=\"([\d\,]+)\"/ ) {
					$params->{$name}->{$k} = $v;
				}
			}
			return "<TMPL_LOOP NAME=\"${name}\">";
		};
		$$text_ref =~ s/<TMPL_LOOP\s+NAME=\"([^\s\t]+)\"\s+([^\>\<]+)>/&{$regexpfilter}($1,$2)/eg;
	};

	my $tmpl_path = $self->{conf}->{BASE_DIR} . "/template/" . $self->{conf}->{FCC_SELECTOR};
	my $tmpl_path_en = $tmpl_path;
	$tmpl_path_en =~ s/\/Mypage$/\/Mypageen/;
	if($lang eq "2" || ($member && $member->{member_lang} == 2)) {
		if(-e $tmpl_path_en) {
			$tmpl_path = $tmpl_path_en;
		}
	}
	my $tmpl_path_list = [$tmpl_path];

	if($seller_id) {
		my $seller_path = "${tmpl_path}/${seller_id}";
		if(-e $seller_path) {
			unshift @{$tmpl_path_list}, $seller_path;
		}
	}

	my $t = HTML::Template->new(
		scalarref => \$tmpl,
		die_on_bad_params => 0,
		vanguard_compatibility_mode => 1,
		loop_context_vars => 1,
		filter => $filter,
		#path => ["$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}"]
		path => $tmpl_path_list,
		case_sensitive => 1
	);
	#
	$self->{tmpl_loop_params} = $params;
	#
	unless($self->{q}) {
		$self->{q} = new CGI;
	}
	#
	while( my($k, $v) = each %{$self->{conf}} ) {
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#
	if($self->{session}->{data}->{member}) {
		my $member = $self->{session}->{data}->{member};
		while( my($k, $v) = each %{$member} ) {
			$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
			if($k =~ /^member_(card|gender)$/) {
				$t->param("session_${k}_${v}" => 1);
			} elsif($k eq "member_note") {
				$v = CGI::Utils->new()->escapeHtml($v);
				$v =~ s/\n/<br \/>/g;
				$t->param("session_${k}" => $v);
			} elsif($k =~ /^member_(point|coupon)$/) {
				$t->param("session_${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
			} elsif($k eq "seller_id") {
				$t->param("session_${k}_${v}" => 1);
			}
		}
	}
	$t->param("epoch" => time);
	return $t;
}

1;
