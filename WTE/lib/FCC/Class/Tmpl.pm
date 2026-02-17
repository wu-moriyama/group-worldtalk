package FCC::Class::Tmpl;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use CGI::Utils;
use Clone;
use HTML::Template;
use FCC::Class::Log;
use FCC::Class::String::Checker;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	#
	$self->{memcache_key_prefix} = "tmpl_";
	#tmplsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		tmpl_id      => '識別ID',
		tmpl_content => 'テンプレートデータ'
	};
	#
	$self->{tmpls} = {
		'reg9001' => "$self->{conf}->{member_caption}仮登録通知メール（$self->{conf}->{member_caption}宛）",
		'reg9002' => "$self->{conf}->{member_caption}本登録通知メール（$self->{conf}->{member_caption}宛）",
		'pwd9001' => "$self->{conf}->{member_caption}パスワード初期化案内通知メール（$self->{conf}->{member_caption}宛）",
		'pwd9002' => "$self->{conf}->{member_caption}パスワード初期化完了通知メール（$self->{conf}->{member_caption}宛）",
		'mpg9001' => "$self->{conf}->{member_caption}退会完了通知メール（$self->{conf}->{member_caption}宛）",
		'mpg9011' => "$self->{conf}->{member_caption}用お問い合わせ通知メール（管理者宛）",
		'mpg9012' => "$self->{conf}->{member_caption}用お問い合わせ通知メール（$self->{conf}->{member_caption}宛）",
		'mpg9013' => "一般用お問い合わせ通知メール（管理者宛）",
		'mpg9014' => "一般用お問い合わせ通知メール（$self->{conf}->{member_caption}宛）",
		'rsv9001' => "$self->{conf}->{member_caption}レッスン予約通知（$self->{conf}->{member_caption}宛）",
		'rsv9002' => "$self->{conf}->{member_caption}レッスン予約通知（$self->{conf}->{prof_caption}宛）",
		'rsv9011' => "$self->{conf}->{member_caption}レッスン・キャンセル通知（$self->{conf}->{member_caption}宛）",
		'rsv9012' => "$self->{conf}->{member_caption}レッスン・キャンセル通知（$self->{conf}->{prof_caption}宛）",
		'rsv9021' => "$self->{conf}->{prof_caption}レッスン・キャンセル通知（$self->{conf}->{member_caption}宛）",
		'rsv9022' => "$self->{conf}->{prof_caption}レッスン・キャンセル通知（$self->{conf}->{prof_caption}宛）",
		'msg9001' => "$self->{conf}->{member_caption}メッセージ送信通知（$self->{conf}->{member_caption}宛）",
		'msg9002' => "$self->{conf}->{member_caption}メッセージ送信通知（$self->{conf}->{prof_caption}宛）",
		'msg9011' => "$self->{conf}->{prof_caption}メッセージ送信通知（$self->{conf}->{member_caption}宛）",
		'msg9012' => "$self->{conf}->{prof_caption}メッセージ送信通知（$self->{conf}->{prof_caption}宛）",
		'rep9001' => "$self->{conf}->{member_caption}レッスン報告通知（管理者宛）",
		'pay9001' => "$self->{conf}->{member_caption}銀行振込通知（$self->{conf}->{member_caption}宛）",
		'pay9002' => "$self->{conf}->{member_caption}銀行振込通知（管理者宛）",
		'buz9001' => "クチコミ投稿通知（$self->{conf}->{member_caption}宛）",
		'buz9002' => "クチコミ投稿通知（$self->{conf}->{prof_caption}宛）",
		'pdm9001' => "$self->{conf}->{prof_caption}請求申請（$self->{conf}->{prof_caption}宛）",
		'pdm9002' => "$self->{conf}->{prof_caption}請求申請（管理者宛）",
		'pdm9011' => "$self->{conf}->{prof_caption}精算通知（$self->{conf}->{prof_caption}宛）",
		'pdm9012' => "$self->{conf}->{prof_caption}精算通知（管理者宛）",
		'sdm9001' => "代理店請求申請（代理店宛）",
		'sdm9002' => "代理店請求申請（管理者宛）",
		'sdm9011' => "代理店精算通知（代理店宛）",
		'sdm9012' => "代理店精算通知（管理者宛）",
		'dwn9001' => "ダウンロード商品購入通知（$self->{conf}->{member_caption}宛）",
		'dwn9002' => "ダウンロード商品購入通知（管理者宛）",
		'lsn9001' => "レッスン開始通知（$self->{conf}->{member_caption}宛）",
		'lsn9002' => "レッスン開始通知（$self->{conf}->{prof_caption}宛）",
		'lsn9011' => "レッスン完了通知（$self->{conf}->{member_caption}宛）",
		'lsn9012' => "レッスン完了通知（$self->{conf}->{prof_caption}宛）",
		'adm9001' => "日別利用状況レポート（管理者宛）",
		'ppl9001' => "カード決済通知（$self->{conf}->{member_caption}宛）",
		'ppl9003' => "カード決済保留通知（管理者宛）",
		'ppl9011' => "カード月次課金決済完了通知（$self->{conf}->{member_caption}宛）",
		'ppl9012' => "カード月次課金決済失敗通知（$self->{conf}->{member_caption}宛）",
		'ppl9021' => "カード月次課金解約通知（$self->{conf}->{member_caption}宛）",
		'pex9001' => "ポイント失効リマインダーメール",
		'prg9001' => "$self->{conf}->{prof_caption}登録申し込み通知メール（管理者宛）",
		'prg9002' => "$self->{conf}->{prof_caption}登録申し込み通知メール（$self->{conf}->{prof_caption}宛）"
	};
}

#---------------------------------------------------------------------

sub get_tmpls {
	my($self) = @_;
	return Clone::clone($self->{tmpls});
}

sub get_tmpl_list {
	my($self) = @_;
	my $tmpls = $self->get_tmpls();
	#
	my $dbh = $self->{db}->connect_db();
	my $sth = $dbh->prepare("SELECT * FROM tmpls");
	$sth->execute();
	my $regs = {};;
	while( my $ref = $sth->fetchrow_hashref ) {
		my $tmpl_id = $ref->{tmpl_id};
		if( $ref->{tmpl_content} ) {
			$regs->{$tmpl_id} = 1;
		} else {
			$regs->{$tmpl_id} = 0;
		}
	}
	$sth->finish();
	#
	my @list;
	for my $tmpl_id ( sort keys %{$tmpls} ) {
		my $tmpl_title = $tmpls->{$tmpl_id};
		my $h = {
			tmpl_id => $tmpl_id,
			tmpl_title => $tmpl_title,
			tmpl_registered => $regs->{$tmpl_id}
		};
		push(@list, $h);
	}
	return \@list;
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#	3.モード（add or mod）指定がない場合は add として処理される
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in) = @_;
	my %cap = %{$self->{table_cols}};
	#
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#テンプレートデータ
		if($k eq "tmpl_content") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 20000) {
				push(@errs, [$k, "\"$cap{$k}\" は20000文字以内で入力してください。"]);
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
sub replace {
	my($self, $ref) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
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
	my $seller_id;
	my $last_sql;
	eval {
		$last_sql = "REPLACE INTO tmpls (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to replace a record to tmpls table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#memcashにセット
	my $tmpl_id = $ref->{tmpl_id};
	my $tmpl_content = $ref->{tmpl_content};
	$self->set_to_memcache($tmpl_id, $tmpl_content);
	#
	return $rec;
}

sub set_to_memcache {
	my($self, $tmpl_id, $tmpl_content) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $tmpl_id;
	my $mem = $self->{memd}->set($mem_key, $tmpl_content);
	unless($mem) {
		my $msg = "failed to set a tmpl record to memcache. : tmpl_id=${tmpl_id}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	return $tmpl_content;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
	my($self, $tmpl_id) = @_;
	#memcacheから取得
	{
		my $data = $self->get_from_memcache($tmpl_id);
		if( $data ) {
			return $data;
		}
	}
	#DBから取得
	{
		my $data = $self->get_from_db($tmpl_id);
		#memcacheにセット
		$self->set_to_memcache($tmpl_id, $data);
		#
		return $data;
	}
}

#---------------------------------------------------------------------
#■識別IDからmemcacheレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_memcache {
	my($self, $tmpl_id) = @_;
	my $key = $self->{memcache_key_prefix} . $tmpl_id;
	my $data = $self->{memd}->get($key);
	if( ! $data ) { return undef; }
	return $data;
}

#---------------------------------------------------------------------
#■識別IDからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
	my($self, $tmpl_id) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $q_tmpl_id = $dbh->quote($tmpl_id);
	#SELECT
	my $ref = $dbh->selectrow_hashref("SELECT tmpl_content FROM tmpls WHERE tmpl_id=${q_tmpl_id}");
	return $ref->{tmpl_content};
}

#---------------------------------------------------------------------
#■テンプレートオブジェクトを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	HTML::Templateのインスタンスを返す。
#---------------------------------------------------------------------
sub get_template_object {
	my($self, $tmpl_id) = @_;
	my $tmpl = $self->get($tmpl_id);
	#HTML::Templateオブジェクトを生成
	my $params = {};
	my $filter = sub {
		my $text_ref = shift;
		my $regexpfilter = sub {
			my($name,$paramstr) = @_;
			my @ary = split(/\s+/, $paramstr);
			for my $pair (@ary) {
				if( my($k, $v) = $pair =~ /^([A-Z\_]+)\=\"([\d\,]+)\"/ ) {
					$params->{$name}->{$k} = $v;
				}
			}
			return "<TMPL_LOOP NAME=\"${name}\">";
		};
		$$text_ref =~ s/<TMPL_LOOP\s+NAME=\"([^\s\t]+)\"\s+([^\>\<]+)>/&{$regexpfilter}($1,$2)/eg;
	};
	my $t = HTML::Template->new(
		scalarref => \$tmpl,
		die_on_bad_params => 0,
		vanguard_compatibility_mode => 1,
		loop_context_vars => 1,
		filter => $filter,
		case_sensitive => 1
	);
	my @parameter_names = $t->param();
	#
	while( my($k, $v) = each %{$self->{conf}} ) {
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#
	return $t;
}

1;
