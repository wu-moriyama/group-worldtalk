package FCC::Action::Admin::SdmtglajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Sdm;
use FCC::Class::Date::Utils;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#代理店請求識別IDを取得
	my $sdm_id = $self->{q}->param("sdm_id");
	if( ! defined $sdm_id || $sdm_id eq "" || $sdm_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#代理店請求情報を取得
	my $osdm = new FCC::Class::Sdm(conf=>$self->{conf}, db=>$self->{db});
	my $sdm = $osdm->get($sdm_id);
	if( ! $sdm ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($sdm->{sdm_id} != $sdm_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#sdm_status
	my $sdm_status = ($sdm->{sdm_status} == 1) ? 2 : 1;
	#アップデート
	$osdm->set_sdm_status($sdm_id, $sdm_status);
	$sdm->{sdm_status} = $sdm_status;
	#
	if($sdm_status == 2) {
		$self->send_mail($sdm);
	}
	#
	$context->{sdm} = $sdm;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#現在日時
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	#
	for my $tmpl_id ("sdm9011", "sdm9012") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k eq "sdm_price") {
				$t->param("${k}_with_comma" =>  FCC::Class::String::Conv->new($v)->comma_format());
			}
		}
		$t->param("ssl_host_url" => $self->{conf}->{ssl_host_url});
		$t->param("sys_host_url" => $self->{conf}->{sys_host_url});
		$t->param("pub_sender" => $self->{conf}->{pub_sender});
		$t->param("pub_from" => $self->{conf}->{pub_from});
		#現在日時
		for( my $i=0; $i<=9; $i++ ) {
			$t->param("tm_${i}" => $tm[$i]);
		}
		#ヘッダーとボディー
		my $eml = $t->output();
		unless($eml) { next; }
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
#	 		die $error;
	 	}
	}
}

1;
