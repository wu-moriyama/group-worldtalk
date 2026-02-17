package FCC::View::Admin::MbrchgcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use FCC::Class::Date::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
	}
	my $t = $self->load_template();
	while( my($k, $v) = each %{$context->{data}} ) {
		if( ! defined $v ) { $v = ""; }
		if($k =~ /^(mbract_cdate|mbract_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
			$t->param($k => $v);
		} elsif($k =~ /^(mbract_type|mbract_reason)$/) {
			$t->param("${k}_${v}" => 1);
			$t->param($k => $v);
		} else {
			$v = CGI::Utils->new()->escapeHtml($v);
			$t->param($k => $v);
		}
	}
	$self->print_html($t);
}

1;
