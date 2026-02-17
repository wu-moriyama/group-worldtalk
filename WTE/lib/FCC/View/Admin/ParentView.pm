package FCC::View::Admin::ParentView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
	}
	my $t = $self->load_template();
	#
	my $note = $context->{note};
	$note = CGI::Utils->new()->escapeHtml($note);
	$note =~ s/\n/<br\/>/g;
	$t->param("note" => $note);
	#
	my $last_logon = $context->{acnt}->{last_logon};
	if($last_logon && ref($last_logon) eq "HASH") {
		while( my($k, $v) = each %{$last_logon} ) {
			if($k eq "tm" && $v) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$t->param("last_logon_${k}_${i}" => $tm[$i]);
				}
			}
			$t->param("last_logon_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	#
	$self->print_html($t);
}

1;
