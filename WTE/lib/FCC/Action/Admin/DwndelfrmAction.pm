package FCC::Action::Admin::DwndelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwndel");
	unless($proc) {
		$proc = $self->create_proc_session_data("dwndel");
		#識別IDを取得
		my $dwn_id = $self->{q}->param("dwn_id");
		if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#インスタンス
		my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		#情報を取得
		my $dwn = $odwn->get($dwn_id);
		unless($dwn) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		if($dwn->{dwn_num}) {
			$context->{fatalerrs} = ["すでに購入があったレコードを削除することはできません。"];
			return $context;
		}
		#
		$proc->{dwn} = $dwn;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
