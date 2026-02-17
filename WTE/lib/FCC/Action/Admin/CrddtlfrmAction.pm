package FCC::Action::Admin::CrddtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Card;
use FCC::Class::Plan;

sub dispatch {
	my($self) = @_;
	my $context = {};

	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crddtl");

	unless($proc) {
		$proc = $self->create_proc_session_data("crddtl");
		#識別IDを取得
		my $crd_id = $self->{q}->param("crd_id");
		if( ! $crd_id || $crd_id !~ /^\d+$/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#カード決済情報を取得
		my $ocrd = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
		my $crd = $ocrd->get($crd_id);
		#プラン情報を取得
		if($crd->{pln_id}) {
			my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
			my $pln = $opln->get($crd->{pln_id});
			if($pln) {
				while( my($k, $v) = each %{$pln} ) {
					$crd->{$k} = $v;
				}
			}
		}
		$proc->{in} = $crd;
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}


1;
