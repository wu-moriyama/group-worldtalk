package FCC::Action::Pwdrst::PwdintcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Pwdrst::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッションを削除
	$self->del_proc_session_data();
	$self->{session}->logoff();

    my $lang = $self->{q}->param("lang");
    if ( $lang eq "2" ) {
        $lang = "2";
    }
    else {
        $lang = "1";
    }

    $context->{lang} = $lang;
	return $context;
}

1;
