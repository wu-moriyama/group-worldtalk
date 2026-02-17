package FCC::Action::Seller::SelmodfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "selmod");
	#インスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#
	if($proc) {
		if( $proc->{in}->{seller_logo_updated} != 1 ) {
			if(  $proc->{in}->{seller_logo_up} || $proc->{in}->{seller_logo_del} eq "1" ) {
				$proc->{in}->{seller_logo_updated} = 1;
			} else {
				#代理店情報を取得
				my $seller_orig = $oseller->get_from_db($proc->{in}->{seller_id});
				#オリジナルのseller_logoをセット
				$proc->{in}->{seller_logo} = $seller_orig->{seller_logo};
			}
		}
	} else  {
		my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
		if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("selmod");
		#代理店情報を取得
		my $seller = $oseller->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		delete $seller->{seller_pass};
		$proc->{in} = $seller;
		$proc->{in}->{seller_logo_updated} = 0;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
