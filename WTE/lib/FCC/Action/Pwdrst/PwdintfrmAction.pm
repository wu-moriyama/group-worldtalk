package FCC::Action::Pwdrst::PwdintfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Pwdrst::_SuperAction);
use FCC::Class::Member;
use Crypt::CBC;
use MIME::Base64;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "pwdrst");
	#
    my $lang = "1";
    if ($proc) {
        $lang = $proc->{in}->{member_lang};
    }
	else {
		$proc = $self->create_proc_session_data("pwdrst");
        my $in_lang = $self->{q}->param('lang');
        if ( $in_lang =~ /^(1|2)$/ ) {
            $lang = $in_lang;
        }
        $proc->{in} = {};
	}
	$proc->{in}->{member_lang} = $lang;

	if( ! $proc->{member_id} ) {
		#トークンを取得して復号化
		my $token = $self->{q}->param("token");
		if( ! $token ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		my $cipher = Crypt::CBC->new(
			-key    => $self->{conf}->{pwdrst_secret_key},
			-cipher => 'Rijndael_PP'
		);
		my $decrypttext = $cipher->decrypt(MIME::Base64::decode_base64($token));
		my($member_id, $member_passphrase, $expire) = split(/\-/, $decrypttext);
		if( $member_id !~ /^\d+$/ || $member_passphrase !~ /^[a-zA-Z0-9]{8}$/ || $expire !~ /^\d+$/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#有効期限のチェック
		if( time > $expire ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#member_idから会員情報を取得
		my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $member = $omember->get($member_id);
		if( ! $member || $member->{member_status} != 1 || $member->{member_passphrase} ne $member_passphrase) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{member_id} = $member_id;
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
