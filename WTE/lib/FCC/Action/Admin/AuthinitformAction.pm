package FCC::Action::Admin::AuthinitformAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Passwd;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#不正アクセスチェック
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) { die $!; }
	if( $pw->get_passwd_num() ) {
		$context->{errs} = ['不正なアクセスです。'];
	}
	return $context;
}

1;
