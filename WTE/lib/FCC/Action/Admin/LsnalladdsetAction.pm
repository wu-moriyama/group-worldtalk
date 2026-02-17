package FCC::Action::Admin::LsnalladdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;

sub dispatch {
    my($self) = @_;
    my $context = {};

    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data($pkey, "lsnalladd");
    
    # セッション切れなどのチェック
    if( ! $proc || ! $proc->{in}->{course_id} ) {
        $context->{fatalerrs} = ["不正なリクエスト、またはセッションの有効期限切れです。"];
        return $context;
    }

    # 登録処理
    my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
    
    # セッションからデータを復元
    my @member_ids = map { s/^\s+|\s+$//g; $_ } split(/\r\n|\r|\n/, $proc->{in}->{member_ids_text});
    @member_ids = grep { /^\d+$/ } @member_ids;

    eval {
        # 登録実行
        my $count = $olsn->add_bulk_from_course($proc->{in}->{course_id}, \@member_ids);
        
        # 完了情報をセッションに保存
        $proc->{done_count} = $count;
        $proc->{done_msg}   = "${count}件の予約を一括登録しました。"; # 完了メッセージ用
        $self->set_proc_session_data($proc);
    };
    
    if ($@) {
        $context->{fatalerrs} = ["登録処理中にシステムエラーが発生しました: $@"];
        return $context;
    }

    # Actionではリダイレクトせず、コンテキストを返してViewに任せる
    $context->{proc} = $proc;
    return $context;
}
1;