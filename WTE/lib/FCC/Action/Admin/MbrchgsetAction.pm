package FCC::Action::Admin::MbrchgsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Mbract;
use FCC::Class::Member;
use FCC::Class::Log;
use FCC::Class::Lesson;
use FCC::Class::Date::Utils;
use Date::Pcalc;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrchg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_id',
		'mbract_reason',
		'mbract_price',
		'member_point_expire_update',
		'expire_not_update'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my @errs = $self->input_check($in);
	#
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		#会員情報を取得
		my $ombract = new FCC::Class::Mbract(conf=>$self->{conf}, db=>$self->{db});
		my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db})->get_from_db($in->{member_id});
		if($member) {
			while( my($k, $v) = each %{$member} ) {
				$in->{$k} = $v;
			}
		} else {
			push(@errs, ["member_id", "「会員識別ID」に指定されたIDは存在しません。"]);
		}
		#
		if($in->{mbract_reason} < 50) {
			$in->{mbract_type} = 1;
		} else {
			$in->{mbract_type} = 2;
		}
		#
#		if($in->{mbract_type} == 2 && $in->{mbract_price} > $member->{member_point}) {
#			push(@errs, ["mbract_price", "指定のポイント数を減算することはできません。"]);
#		}
		#売掛金のチェック
		my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
		my $member_receivable_point = $olsn->get_receivable($in->{member_id}, 1); # ポイントの売り掛け
		my $member_available_point = $member->{member_point} - $member_receivable_point; # 実質的に利用可能なポイント
		if($in->{mbract_type} == 2 && $in->{mbract_price} > $member_available_point) {
			push(@errs, ["mbract_price", "指定のポイント数を減算することはできません。"]);
		}
		#エラーハンドリング
		if(@errs) {
			$proc->{errs} = \@errs;
		} else {
			$proc->{errs} = [];
			#my $rec = $ombract->charge($in);
			my $rec = $self->charge($in);
		}
	}
	#
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub charge {
	my($self, $p) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#membersテーブルのレコード更新SQL
	my $sign = "+";
	if($p->{mbract_type} == 2) {
		$sign = "-";
	}
	my $sql1 = "UPDATE members SET member_point=member_point${sign}$p->{mbract_price} WHERE member_id=$p->{member_id}";
	#mbractsテーブルへのレコード追加SQL
	my $now = time;
	my $price = $p->{mbract_price};
	if($p->{mbract_type} == 2) {
		$price = 0 - $price;
	}
	my $rec = {
		seller_id => $p->{seller_id},
		member_id => $p->{member_id},
		mbract_type => $p->{mbract_type},
		mbract_reason => $p->{mbract_reason},
		mbract_cdate => $now,
		mbract_price => $price
	};
	if($p->{mbract_reason} =~ /^(41|42)$/) {
		if($p->{crd_id}) {
			$rec->{crd_id} = $p->{crd_id};
		}
		if($p->{auto_id}) {
			$rec->{auto_id} = $p->{auto_id};
		}
	}
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		push(@vlist, $v);
	}
	my $sql2 = "INSERT INTO mbracts (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	#ポイント有効期限の延長
	my $sql3;
	unless($p->{expire_not_update}) {
		my $expire_date = $dbh->quote($p->{member_point_expire_update});
		$sql3 = "UPDATE members SET member_point_expire=${expire_date} WHERE member_id=$p->{member_id}";
	}
	#SQL実行
	my $last_sql;
	my $mbract_id;
	eval {
		$last_sql = $sql1;
		my $updated = $dbh->do($sql1);
		if($updated == 0) {
			die "the specified member_id is not found.";
		}
		$last_sql = $sql2;
		$dbh->do($sql2);
		$mbract_id = $dbh->{mysql_insertid};
		if($sql3) {
			$last_sql = $sql3;
			$dbh->do($sql3);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "$@ : ${last_sql}");
		croak $@;
	}

	#SQL文のログ出力
	my $log_fpath = $self->{conf}->{BASE_DIR} . "/data/logs/Admin.Mbrchgset." . $mbract_id . ".log";
	if(open my $fh, ">>", $log_fpath) {
		my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
		my $now = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
		print $fh "[" . $now . "][sql1] " . $sql1 . "\n";
		print $fh "[" . $now . "][sql2] " . $sql2 . "\n";
		print $fh "[" . $now . "][slq3] " . $sql3 . "\n";
		close($fh);
	}

	#
	$rec->{mbract_id} = $mbract_id;
	return $rec;
}

sub input_check {
	my($self, $in) = @_;
	my %caps = (
		member_id => '会員識別ID',
		mbract_reason => '入出金摘要',
		mbract_price => 'ポイント',
		member_point_expire_update => 'ポイント有効期限',
		expire_not_update => 'ポイント有効期限を更新しないフラグ'
	);
	my @errs;
	for my $k ('member_id', 'mbract_reason', 'mbract_price') {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $cap = $caps{$k};
		#会員識別ID
		if($k eq "member_id") {
			if( ! $v ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "「${cap}」は半角数字で指定してください。"]);
			}
		#入出金摘要
		} elsif($k eq "mbract_reason") {
			if( ! $v ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v !~ /^(11|12|13|41|42|43|51|52|91)$/) {
				push(@errs, [$k, "「${cap}」に不正な値が送信されました。"]);
			}
		#ポイント
		} elsif($k eq "mbract_price") {
			if( $v eq "" ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			#} elsif($v == 0) {
			#	push(@errs, [$k, "「${cap}」に0を指定することはできません。"]);
			} elsif($v =~ /^\-/) {
				push(@errs, [$k, "「${cap}」にマイナスを指定することはできません。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "「${cap}」は半角数字で指定してください。"]);
			} elsif($v > 99999999) {
				push(@errs, [$k, "「${cap}」は99999999以内で指定してください。"]);
			}
		#ポイント有効期限を更新しない
		} elsif($k eq "expire_not_update") {
			if($v && $v ne "1") {
				push(@errs, [$k, "「${cap}」に不正な値が送信されました。"]);
			}	
		}
	}
	unless(@errs) {
		#ポイント有効期限
		unless($in->{expire_not_update}) {
			my $k = "member_point_expire_update";
			my $v = $in->{$k};
			my $cap = $caps{$k};
			if($v eq "") {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v !~ /^\d{4}\-\d{2}\-\d{2}$/) {
				push(@errs, [$k, "「${cap}」は YYYY-MM-DD 形式で指定してください。"]);
			} else {
				my($Y, $M, $D) = $v =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;
				$Y += 0;
				$M += 0;
				$D += 0;
				unless(Date::Pcalc::check_date($Y, $M, $D)) {
					push(@errs, [$k, "「${cap}」に指定された日付が正しくありません。"]);
				}
			}
		}
	}
	return @errs;
}

1;
