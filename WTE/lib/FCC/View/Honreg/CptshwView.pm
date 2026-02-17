package FCC::View::Honreg::CptshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Honreg::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}

	my $lang = $context->{lang};
	my $t = $self->load_template(undef, $lang);
	while( my($k, $v) = each %{$context->{seller}} ) {
		$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
	}
	#会員識別ID
	$t->param("member_id" => $context->{member_id});
	#
	$self->print_html($t);
}

1;
