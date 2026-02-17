package FCC::View::Admin::LsnalladdcfmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
    my ($self, $context) = @_;

    # システムエラーの評価
    if ($context->{fatalerrs}) {
        $self->error($context->{fatalerrs});
        exit;
    }

    my $t;
    
    # --- テンプレートの切り替え ---
    if ($context->{template_mode} eq 'input') {
        # エラー時は入力画面に戻る（フルパスを指定）
        my $tmpl_path = "$self->{conf}->{BASE_DIR}/template/Admin/Lsnalladdfrm.html";
        $t = $self->load_template($tmpl_path);
        
        # エラーメッセージの展開
        if ($context->{proc}->{errs} && @{$context->{proc}->{errs}}) {
            my $err_msg = "";
            foreach my $err (@{$context->{proc}->{errs}}) {
                $err_msg .= $err->[1] . "<br />";
            }
            $t->param("errs" => $err_msg);
        }
        
        # 入力値の復元
        my $in = $context->{proc}->{in};
        while (my ($k, $v) = each %{$in}) {
            $t->param($k => CGI::Utils->new()->escapeHtml($v));
        }
    }
    else {
        # 確認画面（フルパスを指定）
        my $tmpl_path = "$self->{conf}->{BASE_DIR}/template/Admin/Lsnalladdcfm.html";
        $t = $self->load_template($tmpl_path);

        # コース情報
        if ($context->{course_info}) {
            $t->param("course_name" => CGI::Utils->new()->escapeHtml($context->{course_info}->{course_name}));
            $t->param("course_id"   => $context->{course_info}->{course_id});
        }

        # 日程リスト
        if ($context->{preview_dates}) {
            $t->param("preview_dates_loop" => $context->{preview_dates});
        }

        # 会員リスト
        $t->param("member_count" => $context->{member_count});
        if ($context->{member_list}) {
            $t->param("member_list_loop" => $context->{member_list});
        }

        # 合計レコード数
        if ($context->{preview_dates} && $context->{member_count}) {
            my $total_recs = scalar(@{$context->{preview_dates}}) * $context->{member_count};
            $t->param("total_records" => $total_recs);
        }
    }

    # 共通パラメータ
    $t->param("pkey" => $context->{proc}->{pkey});
    
    # HTML出力
    $self->print_html($t);
}

1;