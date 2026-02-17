package FCC::Action::Admin::PrfmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Date::Utils;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "prfmod" );

    #インスタンス
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd}, pkey => $pkey, q => $self->{q} );
    #
    if ($proc) {
        if ( $proc->{in}->{prof_logo_updated} != 1 ) {
            if ( $proc->{in}->{prof_logo_up} || $proc->{in}->{prof_logo_del} eq "1" ) {
                $proc->{in}->{prof_logo_updated} = 1;
            }
            else {
                #講師情報を取得
                my $prof_orig = $oprof->get_from_db( $proc->{in}->{prof_id} );

                #オリジナルのprof_logoをセット
                $proc->{in}->{prof_logo} = $prof_orig->{prof_logo};
            }
        }
    }
    else {
        my $prof_id = $self->{q}->param("prof_id");
        if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        $proc = $self->create_proc_session_data("prfmod");

        #講師情報を取得
        my $prof = $oprof->get_from_db($prof_id);
        unless ($prof) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        delete $prof->{prof_pass};
        $proc->{in} = $prof;
        $proc->{in}->{prof_logo_updated} = 0;

        $self->set_proc_session_data($proc);
    }

    #国選択肢リスト
    my $oprof        = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd}, pkey => $pkey, q => $self->{q} );
    my $country_list = $oprof->get_prof_country_list();
    #
    $context->{proc}         = $proc;
    $context->{country_list} = $country_list;
    return $context;
}

1;
