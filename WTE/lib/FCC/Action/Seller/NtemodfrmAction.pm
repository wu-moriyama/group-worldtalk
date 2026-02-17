package FCC::Action::Seller::NtemodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "ntemod");
	#インスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#
	unless($proc) {
		my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
		if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("ntemod");
		#代理店情報を取得
		my $seller = $oseller->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = {
			seller_id => $seller_id,
			seller_note => $seller->{seller_note}
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
