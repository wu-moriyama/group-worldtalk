package FCC::Class::Ccate;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::String::Checker;

sub init {
    my ( $self, %args ) = @_;
    unless ( $args{conf} && $args{db} ) {
        croak "parameters are lacking.";
    }
    $self->{conf} = $args{conf};
    $self->{db}   = $args{db};

    #ccatesテーブルの全カラム名のリスト
    $self->{table_cols} = {
        ccate_id     => "識別ID",
        ccate_pid    => "親カテゴリーID",
        ccate_layer  => "階層の深さ",
        ccate_order  => "同一階層内表示順位",
        ccate_name   => "カテゴリー名",
        ccate_status => "ステータス"
    };
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#  1.入力データのキーのarrayref（必須）
#  2.入力データのhashref（必須）
#[戻り値]
#  エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
    my ( $self, $names, $in ) = @_;
    my %cap = %{ $self->{table_cols} };
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};
        if ( !defined $v ) { $v = ""; }
        my $len     = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
        my $caption = $cap{$k};

        #親カテゴリーID
        if ( $k =~ /^ccate_(id|pid)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^\d+$/ ) {
                push( @errs, [ $k, "\"${caption}\" は数値でなければいけません。" ] );
            }

            #カテゴリー名
        }
        elsif ( $k eq "ccate_name" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 50 ) {
                push( @errs, [ $k, "\"${caption}\" は50文字以内で入力してください。" ] );
            }

            #ステータス
        }
        elsif ( $k eq "ccate_status" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^(0|1)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }
    }
    #
    return @errs;
}

#---------------------------------------------------------------------
#■新規登録
#---------------------------------------------------------------------
#[引数]
#  1.入力データのhashref（必須）
#  {
#    ccate_pid => 親カテゴリーの識別ID (指定がなければ 0),
#    ccate_name => カテゴリー名,
#    ccate_status => ステータス (0 or 1, 指定がなければ 1)
#  }
#
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub add {
    my ( $self, $ref ) = @_;

    #DB接続
    my $dbh = $self->{db}->connect_db();
    #
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }

    unless ( defined $rec->{ccate_status} ) {
        $rec->{ccate_status} = 1;
    }

    #ccate_pid (親カテゴリー識別ID) をチェックして、登録カテゴリーの階層を確定する
    my $pid   = $ref->{ccate_pid};
    my $layer = 1;
    unless ($pid) {
        $pid = 0;
    }
    if ($pid) {
        if ( $pid =~ /^\d+$/ ) {
            my $pcate = $self->get($pid);
            unless ($pcate) {
                croak "ccate_pid is unknown.";
            }
            $layer = $pcate->{ccate_layer} + 1;
        }
        else {
            croak "ccate_pid is invalid.";
        }
    }
    $rec->{ccate_layer} = $layer;

    #親カテゴリーの子カテゴリーすべてを取得して表示順位を確定する
    my $children = $self->get_children( { ccate_id => $pid } );
    my $order    = 1;
    if ( @{$children} ) {
        my $last_cate = pop( @{$children} );
        $order = $last_cate->{ccate_order} + 1;
    }
    $rec->{ccate_order} = $order;

    #SQL生成
    my @klist;
    my @vlist;
    while ( my ( $k, $v ) = each %{$rec} ) {
        push( @klist, $k );
        my $q_v;
        if ( $v eq "" ) {
            $q_v = "NULL";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @vlist, $q_v );
    }

    #INSERT
    my $ccate_id;
    my $last_sql;
    eval {
        $last_sql = "INSERT INTO ccates (" . join( ",", @klist ) . ") VALUES (" . join( ",", @vlist ) . ")";
        $dbh->do($last_sql);
        $ccate_id = $dbh->{mysql_insertid};
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to insert a record to ccates table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #情報を取得
    my $cate = $self->get($ccate_id);
    return $cate;
}

#---------------------------------------------------------------------
#■修正 (カテゴリー名のみ)
#---------------------------------------------------------------------
#[引数]
#  {
#    ccate_id => 識別ID,
#    ccate_name => カテゴリー名,
#    ccate_status => ステータス (0 or 1)
#  }
#
#[戻り値]
#  成功すれば登録データのhashrefを返す。
#  もし存在しないccate_idが指定されたら、未定義値を返す
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
    my ( $self, $ref ) = @_;

    #識別IDのチェック
    my $ccate_id = $ref->{ccate_id};
    if ( !defined $ccate_id || $ccate_id =~ /[^\d]/ ) {
        croak "the value of ccate_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #お知らせ情報を取得
    my $cate_old = $self->get($ccate_id);

    #更新情報をhashrefに格納
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if     ( $k eq "ccate_id" )                 { next; }
        if     ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }

    #ccatesテーブルUPDATE用のSQL生成
    my @sets;
    while ( my ( $k, $v ) = each %{$rec} ) {
        my $q_v;
        if ( $v eq "" ) {
            $q_v = "NULL";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @sets, "${k}=${q_v}" );
    }
    my $sql = "UPDATE ccates SET " . join( ",", @sets ) . " WHERE ccate_id=${ccate_id}";

    #UPDATE
    my $updated;
    eval {
        $updated = $dbh->do($sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a ccate record in ccates table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${sql}" );
        croak $msg;
    }

    #対象のレコードがなければundefを返す
    if ( $updated == 0 ) {
        return undef;
    }

    #情報を取得
    my $cate_new = $self->get($ccate_id);
    return $cate_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#  1.識別ID（必須）
#
#[戻り値]
#  成功すれば削除データのhashrefを返す。
#  失敗すればcroakする。
#  指定の識別IDのカテゴリーに子カテゴリーが存在する場合はcroakする。
#---------------------------------------------------------------------
sub del {
    my ( $self, $ccate_id ) = @_;

    #識別IDのチェック
    if ( !defined $ccate_id || $ccate_id =~ /[^\d]/ ) {
        croak "the value of ccate_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #情報を取得
    my $cate = $self->get($ccate_id);
    unless ($cate) {
        croak "ccate_id was not found.";
    }

    #子カテゴリーを取得
    my $children = $self->get_children( { ccate_id => $ccate_id } );
    if ( @{$children} ) {
        croak "Child categories were found.";
    }

    #SQL生成
    my $sql = "DELETE FROM ccates WHERE ccate_id=${ccate_id}";

    #UPDATE
    eval {
        $dbh->do($sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to delete a ccates record in anns table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${sql}" );
        croak $msg;
    }
    return $cate;
}

#---------------------------------------------------------------------
#■識別IDからカテゴリー情報を取得
#---------------------------------------------------------------------
#[引数]
#  1:識別ID
#[戻り値]
#  hashrefを返す
#---------------------------------------------------------------------
sub get {
    my ( $self, $ccate_id ) = @_;
    if ( !$ccate_id || $ccate_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    my $sql = "SELECT * FROM ccates WHERE ccate_id=${ccate_id}";
    my $ref = $dbh->selectrow_hashref($sql);
    return $ref;
}

#---------------------------------------------------------------------
#■すべてのカテゴリー情報を連想配列で取得
#---------------------------------------------------------------------
#[引数]
#  なし
#[戻り値]
#  hashrefを返す
#---------------------------------------------------------------------
sub get_all {
    my ($self) = @_;

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #select
    my $sql = "SELECT * FROM ccates";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $cates = {};
    while ( my $ref = $sth->fetchrow_hashref ) {
        my $id = $ref->{ccate_id};
        $cates->{$id} = $ref;
    }
    $sth->finish();

    return $cates;
}

#---------------------------------------------------------------------
#■子カテゴリーリストを取得
#---------------------------------------------------------------------
#[引数]
#  1.検索パラメータを格納したhashref（必須ではない）
#  {
#    ccate_id: カテゴリー識別ID (0 または指定なしなら最上位カテゴリーが対象),
#    ccate_status: ステータス (0 or 1)
#  }
#
#[戻り値]
#  [
#    {
#      ccate_id => 1,
#      ccate_pid => 0,
#      ccate_layer => 1,
#      ccate_order => 1,
#      ccate_name => "美容",
#      ccate_status => 1,
#      children => [
#        {
#          ccate_id => 2,
#          ccate_pid => 1,
#          ccate_layer => 2,
#          ccate_order => 1,
#          ccate_name => "エステ"
#          ccate_status => 1,
#          children => []
#        },
#        ...
#      ]
#    },
#    ...
#  ]
#
# - カテゴリー内の表示順位が考慮された配列になる。
# - 検索条件に ccate_id を指定すると、該当のカテゴリーに属する子カテゴリー
#   のリストが返される。
# - 検索対象のカテゴリーが見つからなかった場合は空の配列のリファレンスを返す。
#---------------------------------------------------------------------
sub get_children {
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params         = {};
    my @param_key_list = ( "ccate_id", "ccate_status" );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k =~ /^ccate_(id|status)$/ ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{ccate_status} ) {
        my $v = $params->{ccate_status};
        push( @wheres, "ccate_status=${v}" );
    }

    #select
    my $sql = "SELECT * FROM ccates";
    if (@wheres) {
        my $where = join( " AND ", @wheres );
        $sql .= " WHERE ${where}";
    }
    $sql .= " ORDER BY ccate_layer ASC, ccate_order ASC";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @cate_list;
    my $cates = {};
    while ( my $ref = $sth->fetchrow_hashref ) {
        my $id    = $ref->{ccate_id};
        my $pid   = $ref->{ccate_pid};
        my $laler = $ref->{ccate_layer};
        $ref->{children} = [];

        $cates->{$id} = $ref;
        if ( $ref->{ccate_layer} == 1 ) {
            push( @cate_list, $ref );
        }
        else {
            if ( $cates->{$pid} ) {
                my $pcate = $cates->{$pid};
                push( @{ $pcate->{children} }, $ref );
            }
        }
    }
    $sth->finish();
    if ( $params->{ccate_id} ) {
        my $id   = $params->{ccate_id};
        my $cate = $cates->{$id};
        return $cate->{children};
    }
    else {
        return \@cate_list;
    }
}

#---------------------------------------------------------------------
#■表示順位アップ
#---------------------------------------------------------------------
#[引数]
#  1.識別ID（必須）
#
#[戻り値]
#  成功すれば対象データのhashrefを返す。
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub up {
    my ( $self, $ccate_id ) = @_;

    #識別IDのチェック
    if ( !defined $ccate_id || $ccate_id =~ /[^\d]/ ) {
        croak "The `ccate_id` is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #情報を取得
    my $cate = $self->get($ccate_id);
    unless ($cate) {
        croak "The `ccate_id` was not found.";
    }

    #すでに ccate_order が 1 なら何もせずに終了
    if ( $cate->{ccate_order} == 1 ) {
        return $cate;
    }

    #親カテゴリーから見た子カテゴリー (兄弟カテゴリー) を取得
    my $pid      = $cate->{ccate_pid};
    my $children = $self->get_children( { ccate_id => $pid } );
    unless ( @{$children} ) {
        croak "Any sibling categories were not found.";
    }

    #表示順位が手前のカテゴリーを選定
    my $prev_cate;
    for my $cate ( @{$children} ) {
        if ( $cate->{ccate_id} == $ccate_id ) {
            last;
        }
        else {
            $prev_cate = $cate;
        }
    }
    unless ($prev_cate) {
        croak "The previous category was not found.";
    }

    #SQL
    my $id1    = $prev_cate->{ccate_id};
    my $order1 = $prev_cate->{ccate_order};
    my $id2    = $ccate_id;
    my $order2 = $cate->{ccate_order};
    my $sql1   = "UPDATE ccates SET ccate_order=${order2} WHERE ccate_id=${id1}";
    my $sql2   = "UPDATE ccates SET ccate_order=${order1} WHERE ccate_id=${id2}";

    #UPDATE
    eval {
        $dbh->do($sql1);
        $dbh->do($sql2);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update the `ccate_order`.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@" );
        croak $msg;
    }
    return $cate;
}

#---------------------------------------------------------------------
#■表示順位ダウン
#---------------------------------------------------------------------
#[引数]
#  1.識別ID（必須）
#
#[戻り値]
#  成功すれば対象データのhashrefを返す。
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub down {
    my ( $self, $ccate_id ) = @_;

    #識別IDのチェック
    if ( !defined $ccate_id || $ccate_id =~ /[^\d]/ ) {
        croak "The `ccate_id` is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #情報を取得
    my $cate = $self->get($ccate_id);
    unless ($cate) {
        croak "The `ccate_id` was not found.";
    }

    #親カテゴリーから見た子カテゴリー (兄弟カテゴリー) を取得
    my $pid      = $cate->{ccate_pid};
    my $children = $self->get_children( { ccate_id => $pid } );
    unless ( @{$children} ) {
        croak "Any sibling categories were not found.";
    }

    #すでに ccate_order が兄弟カテゴリーの最後なら何もせずに終了
    my $last_idx = scalar( @{$children} ) - 1;
    if ( $children->[$last_idx]->{ccate_id} == $ccate_id ) {
        return $cate;
    }

    #表示順位が直後のカテゴリーを選定
    my $next_cate;
    for ( my $i = 0 ; $i < @{$children} ; $i++ ) {
        if ( $children->[$i]->{ccate_id} == $ccate_id ) {
            $next_cate = $children->[ $i + 1 ];
            last;
        }
    }
    unless ($next_cate) {
        croak "The next category was not found.";
    }

    #SQL
    my $id1    = $ccate_id;
    my $order1 = $cate->{ccate_order};
    my $id2    = $next_cate->{ccate_id};
    my $order2 = $next_cate->{ccate_order};
    my $sql1   = "UPDATE ccates SET ccate_order=${order2} WHERE ccate_id=${id1}";
    my $sql2   = "UPDATE ccates SET ccate_order=${order1} WHERE ccate_id=${id2}";

    #UPDATE
    eval {
        $dbh->do($sql1);
        $dbh->do($sql2);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update the `ccate_order`.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@" );
        croak $msg;
    }
    return $cate;
}

1;
