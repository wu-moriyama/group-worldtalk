package FCC::Action::Admin::LsnalladdcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my($self) = @_;
    my $context = {};

    # セッション情報の取得
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data($pkey, "lsnalladd");

    # セッションが切れていても、完了画面だけは表示できるようにする場合が多いですが、
    # ここではprocがあれば表示する形にします
    $context->{proc} = $proc;

    return $context;
}

1;