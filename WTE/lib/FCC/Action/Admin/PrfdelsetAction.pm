package FCC::Action::Admin::PrfdelsetAction;
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
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    # FCC:Class::Profインスタンス
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );

    #削除対象の講師識別ID
    my $prof_id = $proc->{prof}->{prof_id};
    if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #削除処理
    $proc->{errs} = [];
    my $prof = $oprof->del($prof_id);
    unless ($prof) {
        $context->{fatalerrs} = ["対象のレコードは登録されておりません。: prof_id=${prof_id}"];
        return $context;
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

1;
