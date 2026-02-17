package FCC::Action::Admin::PdmtglajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Pdm;
use FCC::Class::Date::Utils;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#講師請求識別IDを取得
	my $pdm_id = $self->{q}->param("pdm_id");
	if( ! defined $pdm_id || $pdm_id eq "" || $pdm_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#講師請求情報を取得
	my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
	my $pdm = $opdm->get($pdm_id);
	if( ! $pdm ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($pdm->{pdm_id} != $pdm_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#pdm_status
	my $pdm_status = ($pdm->{pdm_status} == 1) ? 2 : 1;
	#アップデート
	$opdm->set_pdm_status($pdm_id, $pdm_status);
	$pdm->{pdm_status} = $pdm_status;
	#
	if($pdm_status == 2) {
		$self->send_mail($pdm);
	}
	#
	$context->{pdm} = $pdm;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#現在日時
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	#
	for my $tmpl_id ("pdm9011", "pdm9012") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k eq "pdm_price") {
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
