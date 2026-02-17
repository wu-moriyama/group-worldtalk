package FCC::View::Preg::_SuperView;
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
	my $t = $self->load_template("$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}/error.html");
	$t->param('error' => $msg);
	$self->print_html($t);
}

sub load_template {
	my($self, $f) = @_;
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
		} else {
			$self->error404();
		}
	}
	unless( -e $f ) {
		$self->error404();
	}
	#テンプレートファイルをロード
	my $tmpl = File::Read::read_file($f);
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
	my $tmpl_path = "$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}";
	my $tmpl_path_list = [$tmpl_path];
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
	return $t;
}

1;
