package FCC::Action::Admin::LsnemailtoidAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my ($self) = @_;

    # POSTされたメールアドレスのリストを取得
    my $emails_text = $self->{q}->param('emails');
    my @emails = split(/\r\n|\r|\n/, $emails_text);
    
    # 空白除去と有効なリスト作成
    my @clean_emails;
    foreach my $e (@emails) {
        $e =~ s/^\s+|\s+$//g; # 前後の空白削除
        if ($e ne "") {
            push(@clean_emails, $e);
        }
    }

    my @found_ids;

    if (scalar(@clean_emails) > 0) {
        my $dbh = $self->{db}->connect_db();
        
        # プリペアードステートメントで検索
        my $sql = "SELECT member_id FROM members WHERE member_email = ?";
        my $sth = $dbh->prepare($sql);

        foreach my $email (@clean_emails) {
            $sth->execute($email);
            my ($mid) = $sth->fetchrow_array();
            if ($mid) {
                push(@found_ids, $mid);
            }
            $sth->finish();
        }
    }

    # テキスト形式で出力 (Content-Type: text/plain)
    print "Content-Type: text/plain; charset=utf-8\n\n";
    print join("\n", @found_ids);
    exit;
}

1;