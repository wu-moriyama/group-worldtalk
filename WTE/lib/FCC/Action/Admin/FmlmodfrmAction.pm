package FCC::Action::Admin::FmlmodfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "fmlmod");
	#
	unless($proc) {
		my $fml_id = $self->{q}->param("fml_id");
		if( ! defined $fml_id || $fml_id eq "" || $fml_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("fmlmod");
		#情報を取得
		my $fml = FCC::Class::Fml->new(conf=>$self->{conf}, db=>$self->{db})->get($fml_id);
		unless($fml) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $fml;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
