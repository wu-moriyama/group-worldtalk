package FCC::Action::Admin::MbraddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbradd");
	#インスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	unless($proc) {
		$proc = $self->create_proc_session_data("mbradd");
		#代理店識別IDを取得
		my $seller_id = $self->{q}->param("seller_id");
		if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#代理店情報を取得
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{seller} = $seller;
		#初期値
		$proc->{in} = {
			seller_id => $seller_id,
			member_status => 1,
			member_lang => 1
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
