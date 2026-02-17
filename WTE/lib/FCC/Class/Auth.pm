package FCC::Class::Auth;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super FCC::View::_SuperView);
use CGI;
use CGI::Cookie;
use Digest::SHA::PurePerl qw(sha256_hex);
use FCC::Class::Passwd;

sub init {
	my($self, %args) = @_;
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	$self->{q} = $args{q};
	$self->{session} = $args{session};
}

sub dispatch {
	my($self) = @_;
	#管理者ID/PWが登録されていなければ、設定画面を表示
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) { die $!; }
	my $num = $pw->get_passwd_num();
	if($num == 0) {
		if($self->{db} && $self->{db}->{dbh}) {
			$self->{db}->{dbh}->disconnect();
		}
		my $url = $self->{q}->url() . "?m=authinitform";
		print STDOUT "Location: ${url}\n\n";
		exit;
	}
	#認証
	my $sid;
	if( $self->{q}->param('sid') ) {
		$sid = $self->{q}->param('sid');
	} else {
		my %cookies = fetch CGI::Cookie;
		if($cookies{"$self->{conf}->{FCC_SELECTOR}_sid"}) {
			$sid = $cookies{"$self->{conf}->{FCC_SELECTOR}_sid"}->value;
		}
	}
	if($sid) {
		my $session_data = $self->{session}->auth($sid);
		if($session_data) {
			return $session_data;
		} else {
			my $t = $self->load_template("$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}/Autherror.html");
			$t->param('error' => $self->{session}->error);
			my $hdrs = {
				"Set-Cookie" => "$self->{conf}->{FCC_SELECTOR}_sid=dummy; expires=Thu, 01-Jan-1970 00:00:00 GMT;"
			};
			$self->print_html($t, $hdrs);
			exit;
		}
	} else {
		if($self->{db} && $self->{db}->{dbh}) {
			$self->{db}->{dbh}->disconnect();
		}
		my $url = $self->{q}->url() . "?m=authlogonform";
		print STDOUT "Location: ${url}\n\n";
		exit;
	}
}

1;
