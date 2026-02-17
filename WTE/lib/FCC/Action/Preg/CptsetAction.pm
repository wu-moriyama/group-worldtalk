package FCC::Action::Preg::CptsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Preg::_SuperAction);
use CGI::Utils;
use FCC::Class::Prof;
use FCC::Class::String::Checker;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Date::Utils;
use FCC::Class::Tmpl;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "preg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Profインスタンス
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値のname属性値のリスト
	my $in_names = [
		"prof_lastname",
		"prof_firstname",
		"prof_handle",
		"prof_email",
		"prof_pass",
		"prof_pass2",
		"prof_skype_id",
		"prof_zip1",
		"prof_zip2",
		"prof_addr1",
		"prof_addr2",
		"prof_addr3",
		"prof_addr4",
		"prof_tel1",
		"prof_tel2",
		"prof_tel3",
		"prof_gender",
		"prof_country",
		"prof_residence",
		"prof_character",
		"prof_interest",
		"prof_intro",
		"prof_app1",
		"prof_app2",
		"prof_app3",
		"prof_app4"
	];
	#入力値チェック
	my @errs = $oprof->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $in = $proc->{in};
		$in->{prof_status} = 2;	#状態（2:仮登録）
		$in->{prof_order_weight} = 0;
		$in->{prof_reco} = 0;
		$in->{prof_fee} = 0;	#報酬単価
		$in->{prof_rank} = 3;	#ランク
		$in->{prof_step} = $self->{conf}->{prof_default_step};	#トークタイムの単位時間（分）
		$in->{prof_coupon_ok} = 1;	#クーポン利用可否フラグ
		my $prof = $oprof->add($in);
		$proc->{prof} = $prof;
		#本登録案内メール送信
		my $data = {};
		while( my($k, $v) = each %{$prof} ) {
			$data->{$k} = $v;
		}
		my $country_hash = $oprof->get_prof_country_hash();
		$self->send_mail($data, $country_hash);
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in, $country_hash) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($in->{prof_email}) { return; }
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#
	for my $tmpl_id ("prg9001", "prg9002") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k =~ /^prof_(country|residence)$/) {
				$t->param("${k}_name" => CGI::Utils->new()->escapeHtml($country_hash->{$v}));
			} elsif($k eq "prof_gender") {
				$t->param("${k}_${v}" => 1);
			}
		}
		#特徴/興味
		for my $k ('prof_character', 'prof_interest') {
			my $v = $in->{$k} + 0;
			my $bin = unpack("B32", pack("N", $v));
			my @bits = split(//, $bin);
			my @loop;
			for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
				my $title = $self->{conf}->{"${k}${id}_title"};
				my $checked = "";
				if($title eq "") { next; }
				unless( $bits[-$id] ) { next; }
				my $h = {
					id => $id,
					title => CGI::Utils->new()->escapeHtml($title)
				};
				push(@loop, $h);
			}
			$t->param("${k}_loop" => \@loop);
		}
		#
		$t->param("ssl_host_url" => $self->{conf}->{ssl_host_url});
		$t->param("sys_host_url" => $self->{conf}->{sys_host_url});
		$t->param("pub_sender" => $self->{conf}->{pub_sender});
		$t->param("pub_from" => $self->{conf}->{pub_from});
		#ヘッダーとボディー
		my $eml = $t->output();
		my $mail = new FCC::Class::Mail::Sendmail(
			sendmail => $self->{conf}->{sendmail_path},
			smtp_host => $self->{conf}->{smtp_host},
			smtp_port => $self->{conf}->{smtp_port},
			smtp_auth_user => $self->{conf}->{smtp_auth_user},
			smtp_auth_pass => $self->{conf}->{smtp_auth_pass},
			smtp_timeout => $self->{conf}->{smtp_timeout},
			eml => $eml,
			tz => $self->{conf}->{tz}
		);
		$mail->mailsend();
 		if( my $error = $mail->error() ) {
 #			die $error;
 		}
	}
}

1;
