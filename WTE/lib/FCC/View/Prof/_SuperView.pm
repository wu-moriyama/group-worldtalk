package FCC::View::Prof::_SuperView;
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
	exit;
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
	#�e���v���[�g�t�@�C�������[�h
	my $tmpl = File::Read::read_file($f);
	#HTML::Template�I�u�W�F�N�g�𐶐�
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
		path => $tmpl_path_list,
		case_sensitive => 1
	);
	#
	$self->{tmpl_loop_params} = $params;
	#
	unless($self->{q}) {
		$self->{q} = new CGI;
	}
	$t->param('CGI_URL' => $self->{conf}->{CGI_URL});
	$t->param('static_url' => $self->{conf}->{static_url});
	$t->param('product_name' => CGI::Utils->new()->escapeHtml($self->{conf}->{product_name}));
	$t->param('CGI_DIR_URL' => $self->{conf}->{CGI_DIR_URL});
	$t->param('CGI_URL_BASE' => $self->{conf}->{CGI_URL_BASE});
	$t->param('sys_host_url' => $self->{conf}->{sys_host_url});
	while( my($k, $v) = each %{$self->{conf}} ) {
		unless( ref($v) ) {
			$t->param($k => CGI::Utils->new()->escapeHtml($v));
		}
	}
	if($self->{session}->{data}->{prof}) {
		my $prof = $self->{session}->{data}->{prof};
		while( my($k, $v) = each %{$prof} ) {
			$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	$t->param("epoch" => time);
	return $t;
}

1;
