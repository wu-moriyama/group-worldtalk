package FCC::View::Seller::TopView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $seller = $context->{seller};
	my $seller_note = CGI::Utils->new()->escapeHtml($seller->{seller_note});
	$seller_note =~ s/\n/<br\/>/g;
	my $t = $self->load_template();
	$t->param("seller_note" => $seller_note);
	#‚¨’m‚ç‚¹
	my @ann_loop;
	for my $ann (@{$context->{ann_list}}) {
		my %h;
		while( my($k, $v) = each %{$ann} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "ann_cdate") {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$h{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k eq "ann_content") {
				$v = CGI::Utils->new()->escapeHtml($v);
				$v =~ s/(https?\:\/\/[0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?\;\,]+)/<a href=\"$1\" target=\"_blank\">$1<\/a\>/g;
				$v =~ s/\n/<br \/>/g;
				$h{$k} = $v;
			}
		}
		push(@ann_loop, \%h);
	}
	$t->param("ann_loop" => \@ann_loop);
	#
	$self->print_html($t);
}

1;
