package FCC::Action::Seller::PasswdfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "passwd");
	#
	unless($proc) {
		$proc = $self->create_proc_session_data("passwd");
		#営業会社情報を取得
		my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
		my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $seller = $oseller->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = $seller;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

1;
