package FCC::Action::Prof::CouaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Ccate;

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $prof_id = $self->{session}->{data}->{prof}->{prof_id};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "couadd" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("couadd");

        #初期値
        $proc->{in} = {
            prof_id             => $prof_id,
            course_status       => 1,
            course_order_weight => 0,
            course_reco         => 0,
            course_step         => 50,
            course_ccate_id_2   => 0
        };

        $self->set_proc_session_data($proc);
    }

    #カテゴリー取得
    my $occate =
      new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    $context->{ccate_list} = $occate->get_children( { ccate_status => 1 } );
    #
    $context->{proc} = $proc;
    return $context;
}

1;
