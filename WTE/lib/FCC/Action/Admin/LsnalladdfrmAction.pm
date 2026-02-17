package FCC::Action::Admin::LsnalladdfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my($self) = @_;
    my $context = {};

    # プロセスセッションの取得または新規作成
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data($pkey, "lsnalladd");
    
    unless($proc) {
        $proc = $self->create_proc_session_data("lsnalladd");
        $proc->{in} = {};
        $self->set_proc_session_data($proc);
    }

    $context->{proc} = $proc;
    return $context;
}

1;