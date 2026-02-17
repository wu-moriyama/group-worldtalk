package FCC::Action::Reg::FrmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Reg::_SuperAction);
use FCC::Class::Member;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "reg" );

    #インスタンス
    my $omember = new FCC::Class::Member( conf => $self->{conf}, db => $self->{db} );
    my $lang    = "1";
    if ($proc) {
        $lang = $proc->{in}->{member_lang};
    }
    else {
        $proc = $self->create_proc_session_data("reg");
        my $in_lang = $self->{q}->param('lang');
        if ( $in_lang =~ /^(1|2)$/ ) {
            $lang = $in_lang;
        }
        $proc->{in} = {};
    }
    $proc->{in}->{member_lang} = $lang;
    $self->set_proc_session_data($proc);

    $context->{proc} = $proc;
    return $context;
}

1;
