#!/usr/bin/perl
#############################################################
# グループレッスンのステータス自動更新バッチ
# 推奨実行間隔: 5分～1時間に1回 (例: */10 * * * *)
#############################################################
use strict;
use warnings;
BEGIN {
    use DBI;
    use FindBin;
    use lib "$FindBin::Bin/../lib";
    chdir $FindBin::Bin;
    use Config::Tiny;
    use FCC::Class::DB;
    use FCC::Class::Syscnf;
    use FCC::Class::Date::Utils;
    # Logなどは既存の仕組みを利用
}

#############################################################

&main();

sub main {
    &loging("notice", "started.");
    my $start_time = time;

    # 二重起動チェック
    &double_execute_check();

    # 設定ロード
    my $c = &load_conf();

    # DB接続
    my $db = new FCC::Class::DB(conf => $c);
    my $dbh = $db->connect_db();

    # システム設定ロード（必要な場合）
    # my $sc = FCC::Class::Syscnf->new(conf=>$c, db=>$db)->get();

    # 現在日時を取得 (YYYY-MM-DD HH:MM:SS)
    my @tm = FCC::Class::Date::Utils->new(time => time, tz => $c->{tz})->get(1);
    my $now_sql = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $tm[0], $tm[1], $tm[2], $tm[3], $tm[4], $tm[5]);

    &loging("notice", "Check time: $now_sql");

    # -----------------------------------------------------------
    # 1. 「募集中(2)」→「非表示(0)」
    # 条件: course_apply_deadline を過ぎている
    # -----------------------------------------------------------
    {
        my $target_list = $dbh->selectall_arrayref(
            "SELECT course_id, course_name FROM courses WHERE course_status = 2 AND course_apply_deadline <= ?",
            { Slice => {} },
            $now_sql
        );

        for my $row (@$target_list) {
            eval {
                $dbh->do("UPDATE courses SET course_status = 0, course_mdate = ? WHERE course_id = ?", undef, time, $row->{course_id});
                $dbh->commit();
                &loging("notice", "Updated Status 2->0 (Deadline Passed): ID:$row->{course_id} $row->{course_name}");
            };
            if ($@) {
                $dbh->rollback();
                &loging("error", "Failed update 2->0: ID:$row->{course_id} $@");
            }
        }
    }

    # -----------------------------------------------------------
    # 2. 「非表示(0)」→「開催中(1)」 または 「未開催(3)」
    # 条件: course_start_date (日時) を過ぎている
    # 分岐: lessonsテーブルに紐付く予約(lsn_cancel=0)があるかで判定
    # -----------------------------------------------------------
    {
        # サブクエリを使って、lessonsテーブル内の有効な予約数(student_count)を同時に取得します
        my $sql = <<"SQL";
SELECT 
    c.course_id, 
    c.course_name,
    (SELECT COUNT(*) FROM lessons l WHERE l.course_id = c.course_id AND l.lsn_cancel = 0) as student_count
FROM courses c 
WHERE c.course_status = 0 
  AND CONCAT(c.course_start_date, ' ', IFNULL(c.course_time_start, '00:00:00')) <= ?
SQL
        my $target_list = $dbh->selectall_arrayref($sql, { Slice => {} }, $now_sql);

        for my $row (@$target_list) {
            # 予約数を取得
            my $count = $row->{student_count} || 0;
            
            my $new_status;
            my $log_msg;
            
            if ($count > 0) {
                # 予約がある場合 -> 1 (開催中)
                $new_status = 1;
                $log_msg = "Updated Status 0->1 (Started / Students:$count): ID:$row->{course_id} $row->{course_name}";
            } else {
                # 予約がない場合 -> 3 (未開催)
                $new_status = 3;
                $log_msg = "Updated Status 0->3 (Not Held / Students:0): ID:$row->{course_id} $row->{course_name}";
            }

            eval {
                $dbh->do("UPDATE courses SET course_status = ?, course_mdate = ? WHERE course_id = ?", undef, $new_status, time, $row->{course_id});
                $dbh->commit();
                &loging("notice", $log_msg);
            };
            if ($@) {
                $dbh->rollback();
                &loging("error", "Failed update 0->$new_status: ID:$row->{course_id} $@");
            }
        }
    }

    # -----------------------------------------------------------
    # 3. 「開催中(1)」→「終了(4)」
    # 条件: course_end_date (日時) を過ぎている
    # -----------------------------------------------------------
    {
        my $sql = <<"SQL";
SELECT course_id, course_name 
FROM courses 
WHERE course_status = 1 
  AND CONCAT(course_end_date, ' ', IFNULL(course_time_end, '23:59:59')) <= ?
SQL
        my $target_list = $dbh->selectall_arrayref($sql, { Slice => {} }, $now_sql);

        for my $row (@$target_list) {
            eval {
                # 終了ステータスを 4 に変更
                $dbh->do("UPDATE courses SET course_status = 4, course_mdate = ? WHERE course_id = ?", undef, time, $row->{course_id});
                $dbh->commit();
                &loging("notice", "Updated Status 1->4 (Finished): ID:$row->{course_id} $row->{course_name}");
            };
            if ($@) {
                $dbh->rollback();
                &loging("error", "Failed update 1->4: ID:$row->{course_id} $@");
            }
        }
    }

    # DB切断
    $db->disconnect_db();

    # 終了ログ
    &loging("notice", "completed.");
    exit;
}


#############################################################
# サブルーチン (WTEのものを流用)
#############################################################

sub double_execute_check {
    my @script_pathes = split(/\//, $0);
    my $script_name = pop @script_pathes;
    my $ps_result_str = `/bin/ps ux`;
    my @lines = split(/\n/, $ps_result_str);
    my $script_num = 0;
    for my $line (@lines) {
        if($line =~ /\Q${script_name}\E$/) {
            $script_num ++;
            if($script_num > 1) {
                my $msg = "this script has already been running.";
                &loging("error", $msg);
                die "$msg\n";
            }
        }
    }
}

sub load_conf {
    my $c = {};
    # パスは環境に合わせて調整してください
    my $ct = Config::Tiny->read("../default/default.ini.cgi") or &error("failed to read default configurations file.");
    while( my($k, $v) = each %{$ct->{default}} ) {
        $c->{$k} = $v;
    }
    return $c;
}

sub get_jst {
    my($epoch, $zero_pad) = @_;
    unless($epoch) { $epoch = time; }
    my($s, $m, $h, $D, $M, $Y, $w) = gmtime($epoch + 32400);
    $Y += 1900;
    $M ++;
    if($zero_pad) {
        $M = sprintf("%02d", $M);
        $D = sprintf("%02d", $D);
        $h = sprintf("%02d", $h);
        $m = sprintf("%02d", $m);
        $s = sprintf("%02d", $s);
    }
    return $Y, $M, $D, $h, $m, $s, $w;
}

sub loging {
    my($lebel, $msg) = @_;
    $msg =~ s/\n//g;
    my $d = "./logs";
    unless(-d $d){ mkdir $d; } # ディレクトリがなければ作成
    my($script) = $0 =~ /([^\/]+)$/;
    my @tm = &get_jst(time, 1);
    my $now = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
    my $f = "${d}/$tm[0]$tm[1]$tm[2].log";
    open my $fh, ">>", $f or warn "failed to open log: $f";
    print $fh "${now} \[${lebel}\]\[${script}\] ${msg}\n";
    close($fh);
}

sub error {
    my($msg) = @_;
    &loging("error", $msg);
    die "${msg}\n";
}