package FCC::View::Pwdrst::PwdintsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Pwdrst::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};
	my $lang = $context->{proc}->{in}->{member_lang};
	#
	my $seller_id = $self->{seller}->{seller_id};
	if(@{$context->{proc}->{errs}}) {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=pwdintfrm&pkey=${pkey}&lang=${lang}";
		print "Location: ${rurl}\n\n";
	} else {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=pwdintcpt&pkey=${pkey}&lang=${lang}";
		print "Location: ${rurl}\n\n";
	}
}

1;
