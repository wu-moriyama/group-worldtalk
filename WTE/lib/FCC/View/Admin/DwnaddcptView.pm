package FCC::View::Admin::DwnaddcptView;
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
	}
	my $t = $self->load_template();
	while( my($k, $v) = each %{$context->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^dwn_(type|loc|status)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^dwn_(intro|note)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k =~ /^dwn_(point|num)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	$self->print_html($t);
}

1;
