package FCC::Action::Admin::LsnalladdcfmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Course;
use FCC::Class::Member;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    # プロセスセッション確認
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data($pkey, "lsnalladd");
    unless ($proc) {
        $context->{fatalerrs} = ["セッションが無効です。最初からやり直してください。"];
        return $context;
    }

    # 入力値の取得
    my $in_names = ['course_id', 'member_ids_text'];
    my $in = $self->get_input_data($in_names);
    while (my ($k, $v) = each %{$in}) {
        $proc->{in}->{$k} = $v;
    }

    # 入力値チェック
    my @errs = $self->input_check($in_names, $proc->{in});

    if (@errs) {
        $proc->{errs} = \@errs;
        $context->{template_mode} = "input";
    }
    else {
        $proc->{errs} = [];

        # コース情報の取得
        my $ocourse = new FCC::Class::Course(conf => $self->{conf}, db => $self->{db});
        my $course = $ocourse->get($proc->{in}->{course_id});

        unless ($course) {
            $proc->{errs} = [["course_id", "指定されたコースIDが見つからないか、設定が不正です。"]];
            $context->{template_mode} = "input";
        }
        else {
            # プレビューデータの作成
            my $olsn = new FCC::Class::Lesson(conf => $self->{conf}, db => $self->{db});
            my $preview = $olsn->get_course_schedule_preview($proc->{in}->{course_id});

            if (!$preview) {
                $proc->{errs} = [["course_id", "コースの設定が不正です。（日付形式など）"]];
                $context->{template_mode} = "input";
            }
            else {
                # メンバーIDの整形
                my @member_ids = map { s/^\s+|\s+$//g; $_ } split(/\r\n|\r|\n/, $proc->{in}->{member_ids_text});
                @member_ids = grep { /^\d+$/ } @member_ids;

                if (!scalar(@member_ids)) {
                    $proc->{errs} = [["member_ids_text", "有効な会員IDがありません。"]];
                    $context->{template_mode} = "input";
                }
                else {
                    # 会員情報の取得 (確認画面用)
                    # ★修正箇所：memd引数の追加とカンマの確認
                    my $omember = new FCC::Class::Member(
                        conf => $self->{conf}, 
                        db   => $self->{db}, 
                        memd => $self->{memd}
                    );
                    
                    my @member_list;
                    foreach my $mid (@member_ids) {
                        my $mem = $omember->get($mid);
                        if ($mem) {
                            push @member_list, {
                                member_id   => $mid,
                                member_name => "$mem->{member_lastname} $mem->{member_firstname} ($mem->{member_handle})"
                            };
                        } else {
                             push @member_list, {
                                member_id   => $mid,
                                member_name => "ID: $mid (未登録)"
                            };
                        }
                    }

                    # 確認画面用データをコンテキストにセット
                    $context->{preview_dates} = $preview->{dates};
                    $context->{course_info}   = $preview->{course};
                    $context->{member_count}  = scalar(@member_ids);
                    $context->{member_list}   = \@member_list;
                    $context->{template_mode} = "confirm";
                }
            }
        }
    }

    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    
    return $context;
}

sub input_check {
    my ($self, $names, $in) = @_;
    my @errs;

    if (!defined $in->{course_id} || $in->{course_id} eq "") {
        push(@errs, ["course_id", "コースIDは必須です。"]);
    }
    elsif ($in->{course_id} =~ /[^\d]/) {
        push(@errs, ["course_id", "コースIDは半角数字で入力してください。"]);
    }

    if (!defined $in->{member_ids_text} || $in->{member_ids_text} eq "") {
        push(@errs, ["member_ids_text", "会員IDリストは必須です。"]);
    }

    return @errs;
}

1;