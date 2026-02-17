package FCC::Action::Admin::DctaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#カテゴリーを取得
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $cates = $odct->get_from_db();
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dctadd");
	unless($proc) {
		$proc = $self->create_proc_session_data("dctadd");
		$proc->{in} = {
			dct_status => 1
		};
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
