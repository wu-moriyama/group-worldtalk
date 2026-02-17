package FCC::Action::Admin::FmldelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Fml;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "fmldel");
	unless($proc) {
		my $fml_id = $self->{q}->param("fml_id");
		if( ! defined $fml_id || $fml_id eq "" || $fml_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("fmldel");
		#インスタンス
		my $ofml = new FCC::Class::Fml(conf=>$self->{conf}, db=>$self->{db});
		#情報を取得
		my $fml = $ofml->get($fml_id);
		unless($fml) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $fml;
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
