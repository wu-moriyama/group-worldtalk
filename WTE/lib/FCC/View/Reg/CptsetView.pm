package FCC::View::Reg::CptsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Reg::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#代理店ID
	my $seller = $self->{session}->{data}->{seller};
	my $seller_id = "";
	if($seller->{seller_id}) {
		$seller_id = $seller->{seller_id};
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};

	my $lang = $context->{proc}->{in}->{member_lang};
	#
	if(@{$context->{proc}->{errs}}) {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=frmshw&pkey=${pkey}&lang=${lang}";
		print "Location: ${rurl}\n\n";
	} else {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=cptshw&pkey=${pkey}&s=${seller_id}&lang=${lang}";
		print "Location: ${rurl}\n\n";
	}
}

1;
