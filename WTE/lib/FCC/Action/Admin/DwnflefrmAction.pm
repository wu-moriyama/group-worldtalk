package FCC::Action::Admin::DwnflefrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwnfle");
	#インスタンス
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, pkey=>$pkey, q=>$self->{q});
	#
	unless($proc) {
		my $dwn_id = $self->{q}->param("dwn_id");
		if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("dwnfle");
		#情報を取得
		my $dwn = $odwn->get($dwn_id);
		unless($dwn) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		if($dwn->{dwn_loc} != 1) {
			$context->{fatalerrs} = ["商品保存場所がローカルでない商品にファイルをアップロードすることはできません。"];
			return $context;
		}
		$proc->{in} = $dwn;
		#
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
