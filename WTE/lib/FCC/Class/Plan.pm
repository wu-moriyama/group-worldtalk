package FCC::Class::Plan;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use FCC::Class::String::Checker;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#plansテーブルの全カラム名のリスト
	$self->{table_cols} = {
		pln_id           => "識別ID",
		pln_title        => "プラン名称",
		pln_subscription => "自動課金フラグ",
		pln_price        => "課金額",
		pln_point        => "ポイント",
		pln_status       => "状態",
		pln_sort         => "表示順"
	};
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
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#識別ID
		if($k eq "pln_id") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^a-zA-Z0-9]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角英数のみで指定してください。"]);
			} elsif($len > 50) {
				push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
			}
		#プラン名称
		} elsif($k eq "pln_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で入力してください。"]);
			}
		#自動課金フラグ
		} elsif($k eq "pln_subscription") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#課金額
		} elsif($k eq "pln_price") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} else {
				$v += 0;
				if($v < 1 || $v > 1000000) {
					push(@errs, [$k, "\"$cap{$k}\" は1～1000000の範囲内で指定してください。"]);
				} else {
					$in->{$k} = $v;
				}
			}
		#ポイント
		} elsif($k eq "pln_point") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} else {
				$v += 0;
				if($v < 0 || $v > 1000000) {
					push(@errs, [$k, "\"$cap{$k}\" は0～1000000の範囲内で指定してください。"]);
				} else {
					$in->{$k} = $v;
				}
			}
		#状態
		} elsif($k eq "pln_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#表示順
		} elsif($k eq "pln_sort") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} else {
				$v += 0;
				if($v < 1 || $v > 255) {
					push(@errs, [$k, "\"$cap{$k}\" は1～255の範囲内で指定してください。"]);
				} else {
					$in->{$k} = $v;
				}
			}
		}
	}
	#
	return @errs;
}

#---------------------------------------------------------------------
#■識別IDからレコード取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $pln_id) = @_;
	if( ! $pln_id ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_pln_id = $dbh->quote($pln_id);
	my $sql = "SELECT * FROM plans";
	$sql .= " WHERE pln_id=${q_pln_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■プラン一括登録
#---------------------------------------------------------------------
#[引数]
#	1: arrayref
#[戻り値]
#	登録したhashref
#---------------------------------------------------------------------
sub set {
	my($self, $list) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQL生成
	my @sql_list = ("TRUNCATE TABLE plans");
	my $sort = 1;
	for my $ref (@{$list}) {
		my $rec = {};
		while( my($k, $v) = each %{$ref} ) {
			unless( exists $self->{table_cols}->{$k} ) { next; }
			if( defined $v ) {
				$rec->{$k} = $v;
			} else {
				$rec->{$k} = "";
			}
		}
		$rec->{pln_sort} = $sort * 10;
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
		my $sql = "INSERT INTO plans (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		push(@sql_list, $sql);
		$sort ++;
	}
	#SQL実行
	my $last_sql;
	eval {
		for my $sql (@sql_list) {
			$last_sql = $sql;
			$dbh->do($last_sql);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to plans table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#全プラン情報を取得
	my $list = $self->get_all();
	#
	return $list;
}

#---------------------------------------------------------------------
#■全プラン情報を取得
#---------------------------------------------------------------------
#[引数]
#[戻り値]
#---------------------------------------------------------------------
sub get_all {
	my($self, $params) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#フェッチ
	my $sql = "SELECT * FROM plans";
	if( $params && defined $params->{pln_status} && $params->{pln_status} =~ /^(0|1)$/ ) {
		my $s = $params->{pln_status};
		$sql .= " WHERE pln_status=${s}";
	}
	$sql .= " ORDER BY pln_sort ASC";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $list = [];
	while( my $ref = $sth->fetchrow_hashref ) {
		if($ref) {
			$self->add_info($ref);
		}
		push(@{$list}, $ref);
	}
	$sth->finish();
	#
	return $list;
}

sub add_info {
	my($self, $ref) = @_;
	#消費税抜きの金額
	if($ref->{pln_price}) {
		$ref->{pln_tax_rate} = $self->{conf}->{tax_rate};
		$ref->{pln_price_excluding_tax} = int($ref->{pln_price} * 100 / (100 + $self->{conf}->{tax_rate}));
	}	
}
1;
