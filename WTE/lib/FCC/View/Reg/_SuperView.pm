package FCC::View::Reg::_SuperView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::_SuperView);

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

	my $in = $self->{session}->{data}->{proc}->{in};
	my $lang = "1";
	if($in && $in->{member_lang} && $in->{member_lang} eq "2") {
		$lang = "2";
	}

	my $dpath = $self->{conf}->{BASE_DIR} . "/template/" . $self->{conf}->{FCC_SELECTOR};
	my $fpath = $dpath . "/error.html";
	if($lang eq "2") {
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
	my($self, $f, $lang) = @_;
	my $seller_id = 0;
	my $seller = $self->{session}->{data}->{seller};
	if($seller) {
		$seller_id = $seller->{seller_id};
	}

	unless($lang) {
		my $in = $self->{session}->{data}->{proc}->{in};
		if($in && $in->{member_lang} && $in->{member_lang} eq "2") {
			$lang = "2";
		} else {
			$lang = "1";
		}
	}

	unless($f) {
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
	unless( -e $f ) {
		$self->error404();
	}

	if($lang eq "2") {
		my $f_en = $f;
		$f_en =~ s/\/Reg\//\/Regen\//;
		if(-e $f_en) {
			$f = $f_en;
		}
	}

	my $tmpl = File::Read::read_file($f);
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
	if($lang eq "2") {
		my $tmpl_path_en = $tmpl_path;
		$tmpl_path_en =~ s/\/Reg$/\/Regen/;
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
		path => $tmpl_path_list
	);
	unless($self->{q}) {
		$self->{q} = new CGI;
	}
	#
	while( my($k, $v) = each %{$self->{conf}} ) {
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#
	if($self->{session}->{data}->{seller}) {
		my $seller = $self->{session}->{data}->{seller};
		while( my($k, $v) = each %{$seller} ) {
			$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
			if($k =~ /^(seller_pay|member_card)$/) {
				$t->param("session_${k}_${v}" => 1);
			}
		}
	}
	#
	return $t;
}

1;
