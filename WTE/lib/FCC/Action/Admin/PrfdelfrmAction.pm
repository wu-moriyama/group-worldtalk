package FCC::Action::Admin::PrfdelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Prof;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "prfdel" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("prfdel");

        #講師識別IDを取得
        my $prof_id = $self->{q}->param("prof_id");
        if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }

        #インスタンス
        my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db} );

        #講師情報を取得
        my $prof = $oprof->get_from_db($prof_id);
        unless ($prof) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }

        #国選択肢リスト
        my $country_hash = $oprof->get_prof_country_hash();
        if ( $prof->{prof_country} ) {
            $prof->{prof_country_name} = $country_hash->{ $prof->{prof_country} };
        }
        if ( $prof->{prof_residence} ) {
            $prof->{prof_residence_name} = $country_hash->{ $prof->{prof_residence} };
        }
        #
        $proc->{prof} = $prof;
        #
        $self->set_proc_session_data($proc);
    }
    $context->{proc} = $proc;
    return $context;
}

1;
