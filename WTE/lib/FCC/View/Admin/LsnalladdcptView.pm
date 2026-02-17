package FCC::View::Admin::LsnalladdcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
    my ($self, $context) = @_;

    # テンプレート読み込み（絶対パスで指定）
    my $tmpl_path = "$self->{conf}->{BASE_DIR}/template/Admin/Lsnalladdcpt.html";
    my $t = $self->load_template($tmpl_path);

    # 完了メッセージの表示
    if ($context->{proc} && $context->{proc}->{done_msg}) {
        $t->param("done_msg" => CGI::Utils->new()->escapeHtml($context->{proc}->{done_msg}));
    }
    # 件数の表示
    if ($context->{proc} && $context->{proc}->{done_count}) {
        $t->param("done_count" => $context->{proc}->{done_count});
    }

    # HTML出力
    $self->print_html($t);
    
    # (オプション) 完了画面が表示されたら、もう不要なのでセッションを削除する
    # $self->del_proc_session_data(); 
}

1;