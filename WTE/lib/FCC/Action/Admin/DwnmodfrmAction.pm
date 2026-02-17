package FCC::Action::Admin::DwnmodfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "dwnmod");
	#インスタンス
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#
	if($proc) {
		if( $proc->{in}->{dwn_logo_updated} != 1 ) {
			if(  $proc->{in}->{dwn_logo_up} || $proc->{in}->{dwn_logo_del} eq "1" ) {
				$proc->{in}->{dwn_logo_updated} = 1;
			} else {
				#情報を取得
				my $dwn_orig = $odwn->get($proc->{in}->{dwn_id});
				#オリジナルのdwn_logoをセット
				$proc->{in}->{dwn_logo} = $dwn_orig->{dwn_logo};
			}
		}
	} else {
		my $dwn_id = $self->{q}->param("dwn_id");
		if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("dwnmod");
		#情報を取得
		my $dwn = $odwn->get($dwn_id);
		unless($dwn) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = $dwn;
		$proc->{in}->{dwn_logo_updated} = 0;
		#
		$self->set_proc_session_data($proc);
	}
	#カテゴリーリスト
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $dct_list = $odct->get_available_list();
	#
	$context->{proc} = $proc;
	$context->{dct_list} = $dct_list;
	return $context;
}

1;
