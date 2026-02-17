package FCC::Action::Admin::DctmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dctmod");
	#インスタンス
	my $odtc = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#
	unless($proc) {
		my $dct_id = $self->{q}->param("dct_id");
		if( ! defined $dct_id || $dct_id eq "" || $dct_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("dctmod");
		#カテゴリー情報を取得
		my $dcts = $odtc->get();
		unless($dcts->{$dct_id}) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = $dcts->{$dct_id};
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
