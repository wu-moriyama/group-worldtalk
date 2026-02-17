package FCC::View::Admin::SchaddsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};
	#日付
	my $d = $context->{proc}->{in}->{d};
	if( ! $d ) { $d = ""; }
	my $prof_id = $context->{proc}->{in}->{prof_id};
	#
	if(@{$context->{proc}->{errs}}) {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=schlstfrm&d=${d}&pkey=${pkey}&prof_id=${prof_id}";
		print "Location: ${rurl}\n\n";
	} else {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=schlstfrm&d=${d}&prof_id=${prof_id}";
		print "Location: ${rurl}\n\n";
	}
}

1;
