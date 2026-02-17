package FCC::Class::Dct;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::String::Checker;
use FCC::Class::Date::Utils;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	#
	$self->{memcache_key} = "dcts";
	#dctsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		dct_id     => '識別ID',
		dct_title  => 'カテゴリー名称',
		dct_sort   => '表示順',
		dct_status => '状態',
		dct_items  => '商品点数（販売点数）'
	};
	#
	$self->{dcts} = undef;
}

#---------------------------------------------------------------------
#■表示順を上げる
#---------------------------------------------------------------------
#[引数]
#	カテゴリー識別ID
#[戻り値]
#	変更後の全カテゴリー情報を格納したhashref
#---------------------------------------------------------------------
sub sort_up {
	my($self, $dct_id) = @_;
	my $dcts = $self->_sort($dct_id, "up");
	return $dcts;
}

#---------------------------------------------------------------------
#■表示順を下げる
#---------------------------------------------------------------------
#[引数]
#	商品プラン識別ID
#[戻り値]
#	変更後の表示順
#---------------------------------------------------------------------
sub sort_dn {
	my($self, $dct_id) = @_;
	my $dcts = $self->_sort($dct_id, "dn");
	return $dcts;
}

sub _sort {
	my($self, $dct_id, $direction) = @_;
	if( ! $dct_id || $dct_id =~ /[^\d]/ ) {
		croak "the 1st augument must be a number.";
	}
	my $dcts = $self->get();
	unless($dcts->{$dct_id}) {
		croak "the specified dct_id is not found.";
	}
	my %targets;
	while( my($id, $ref) = each %{$dcts} ) {
		$targets{$id} = $ref->{dct_sort} * 10;
	}
	if($direction eq "dn") {
		$targets{$dct_id} += 15;
	} elsif($direction eq "up") {
		$targets{$dct_id} -= 15;
	} else {
		croak "invalid parameter.";
	}
	my $sort = 1;
	for my $id ( sort { $targets{$a}<=>$targets{$b} } keys %targets ) {
		$targets{$id} = $sort;
		$sort ++;
	}
	my $new_dcts = $self->_sort_update(\%targets);
	return $new_dcts;
}

sub _sort_update {
	my($self, $targets) = @_;
	#DBをアップデート
	my $dbh = $self->{db}->connect_db();
	my $last_sql;
	eval {
		while( my($id, $sort) = each %{$targets} ) {
			my $sql = "UPDATE dcts SET dct_sort=${sort} WHERE dct_id=${id}";
			$last_sql = $sql;
			$dbh->do($sql);
		}
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a record in dcts table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#memcacheをアップデート
	my $dcts = $self->get_from_db();
	$self->set_to_memcache($dcts);
	#
	$self->{dcts} = $dcts;
	#
	return $dcts;
}

#---------------------------------------------------------------------
#■有効なカテゴリーのリストを取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したarrayを返す。
#---------------------------------------------------------------------
sub get_available_list {
	my($self) = @_;
	my $dcts = $self->get();
	my $list = [];
	for my $id ( sort { $dcts->{$a}->{dct_sort} <=> $dcts->{$b}->{dct_sort} } keys %{$dcts} ) {
		if( $dcts->{$id}->{dct_status} == 1 ) {
			push(@{$list}, $dcts->{$id});
		}
	}
	return $list;
}

#---------------------------------------------------------------------
#■カテゴリーのリストを取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したarrayを返す。
#---------------------------------------------------------------------
sub get_all_list {
	my($self) = @_;
	my $dcts = $self->get();
	my $list = [];
	for my $id ( sort { $dcts->{$a}->{dct_sort} <=> $dcts->{$b}->{dct_sort} } keys %{$dcts} ) {
		push(@{$list}, $dcts->{$id});
	}
	return $list;
}

#---------------------------------------------------------------------
#■全レコードを取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
	my($self) = @_;
	#
	if($self->{dcts}) {
		return $self->{dcts};
	}
	#
	#memcacheから取得
	{
		my $ref = $self->get_from_memcache();
		if( $ref && $ref->{0} ) {
			$self->{dcts} = $ref;
			return $ref;
		}
	}
	#DBから取得
	{
		my $ref = $self->get_from_db();
		#memcacheにセット
		$self->set_to_memcache($ref);
		#
		$self->{dcts} = $ref;
		return $ref;
	}
}

#---------------------------------------------------------------------
#■memcacheレコードを取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_memcache {
	my($self) = @_;
	my $dcts = $self->{memd}->get($self->{memcache_key});
	return $dcts;
}

#---------------------------------------------------------------------
#■DBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
	my($self) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sth = $dbh->prepare("SELECT * FROM dcts");
	$sth->execute();
	my $dcts = {};
	while( my $ref = $sth->fetchrow_hashref ) {
		my $dct_id = $ref->{dct_id};
		unless($dct_id) { next; }
		$dcts->{$dct_id} = $ref;
	}
	$sth->finish();
	$self->{dcts} = $dcts;
	return $dcts;
}

#---------------------------------------------------------------------
#■レコードをmemcacheにセット
#---------------------------------------------------------------------
#[引数]
#	全レコードを格納したhashref
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub set_to_memcache {
	my($self, $ref) = @_;
	if( ! defined $ref || ref($ref) ne "HASH" ) {
		croak "the 1st augument must be a hashref.";
	}
	my $mem = $self->{memd}->set($self->{memcache_key}, $ref);
	unless($mem) {
		my $msg = "failed to set a dcts records to memcache.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	return $ref;
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in) = @_;
	my %cap = %{$self->{table_cols}};
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		#カテゴリー名称
		if($k eq "dct_title") {
			my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
			}
		#状態
		} elsif($k eq "dct_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
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
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub add {
	my($self, $ref) = @_;
	if( ! defined $ref || ref($ref) ne "HASH" ) {
		croak "the 1st augument must be a hashref.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#dct_sortの特定
	my($dct_sort) = $dbh->selectrow_array("SELECT COALESCE(MAX(dct_sort) + 1, 1) FROM dcts");
	#
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	$rec->{dct_sort} = $dct_sort;
	#SQL生成
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@vlist, $q_v);
	}
	#INSERT
	my $dct_id;
	my $sql = "INSERT INTO dcts (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	eval {
		$dbh->do($sql);
		$dct_id = $dbh->{mysql_insertid};
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to dcts table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#カテゴリー情報を取得
	my $dcts_new = $self->get_from_db();
	#memcashにセット
	$self->set_to_memcache($dcts_new);
	#
	$self->{dcts} = $dcts_new;
	#
	return $dcts_new->{$dct_id};
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないdct_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $dct_id = $ref->{dct_id};
	if( ! defined $dct_id || $dct_id =~ /[^\d]/) {
		croak "the value of dct_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#カテゴリー情報を取得
	my $dcts = $self->get();
	my $old_cate = $dcts->{$dct_id};
	if( ! $old_cate ) {
		croak "the specified dct_id is not found.";
	}
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "dct_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#dctsテーブルUPDATE用のSQL生成
	my @sets;
	while( my($k, $v) = each %{$rec} ) {
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@sets, "${k}=${q_v}");
	}
	my $sql = "UPDATE dcts SET " . join(",", @sets) . " WHERE dct_id=${dct_id}";
	#UPDATE
	my $updated;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a record in dcts table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#カテゴリー情報を取得
	my $dcts_new = $self->get_from_db();
	#memcashにセット
	$self->set_to_memcache($dcts_new);
	#
	$self->{dcts} = $dcts_new;
	#
	return $dcts_new->{$dct_id};
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのdct_idを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $dct_id) = @_;
	#識別IDのチェック
	if( ! defined $dct_id || $dct_id =~ /[^\d]/ || $dct_id < 1) {
		croak "the value of dct_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#カテゴリー情報を取得
	my $dcts = $self->get_from_db();
	if( ! $dcts->{$dct_id} ) {
		croak "the specified dct_id is not found.";
	}
	#DELETE
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM dcts WHERE dct_id=${dct_id}";
		$dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in dcts table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#カテゴリー情報を取得
	my $dcts_new = $self->get_from_db();
	#memcashにセット
	$self->set_to_memcache($dcts_new);
	#
	$self->{dcts} = $dcts_new;
	#
	return $dct_id;
}

1;
