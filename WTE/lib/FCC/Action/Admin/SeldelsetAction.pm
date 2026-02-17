package FCC::Action::Admin::SeldelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "seldel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Siteインスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#削除対象の代理店識別ID
	my $seller_id = $proc->{in}->{seller_id};
	if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $seller = $oseller->del($seller_id);
	unless($seller) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: seller_id=${seller_id}"];
		return $context;
	}
	$proc->{in} = $seller;
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
