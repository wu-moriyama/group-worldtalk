package FCC::ControllerSeller;
$VERSION = 1.00;
use strict;
use warnings;
use File::Basename;
use CGI;
use Config::Tiny;
use Cache::Memcached::Fast;
use CGI::Cookie;
use FCC::Class::DB;
use FCC::Class::Syscnf;
use FCC::Class::SellerSession;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = { params => $args{params} };
	bless $self, $class;
	return $self;
}

sub dispatch {
	my($self) = @_;
	#CGI.pmのインスタンス
	$self->{q} = new CGI;
	#設定を取り出す
	my $c = $self->load_conf();
	#呼び出されたCGIのURL
	$c->{CGI_URL} = $self->{q}->url();	# http://www.futomi.com/framework/admin.cgi
	$c->{CGI_URL_PATH} = $self->{q}->url(-absolute=>1);	# /framework/admin.cgi
	$c->{CGI_DIR_URL} = File::Basename::dirname($c->{CGI_URL});	# http://www.futomi.com/framework
	$c->{CGI_DIR_URL_PATH} = File::Basename::dirname($c->{CGI_URL_PATH});	# /framework
	($c->{CGI_URL_BASE}) = $c->{CGI_URL} =~ /^(https?\:\/\/[^\/]+)/;
	#
	my($sys_host_url) = $c->{CGI_URL} =~ /^(https?\:\/\/[^\/]+)/;
	if($sys_host_url) {
		$c->{sys_host_url} = $sys_host_url;
	}
	#memcachedに接続
	my @memcached_servers;
	if( $c->{memcached_servers1} ) {
		push(@memcached_servers, $c->{memcached_servers1});
	}
	if( $c->{memcached_servers2} ) {
		push(@memcached_servers, $c->{memcached_servers2});
	}
	my $memd = new Cache::Memcached::Fast({
		servers => \@memcached_servers,
		ketama_points => 150
	});
	#DB初期化
	my $db = new FCC::Class::DB(conf => $c);
	#システム設定情報を取得
	my $sc = FCC::Class::Syscnf->new(conf=>$c, db=>$db, memd=>$memd, force_db=>1)->get();
	while( my($k, $v) = each %{$sc} ) {
		$c->{$k} = $v;
	}
	#アクセスされたCGIファイル名からセレクターを取り出す
	my $f = $self->get_selector();
	$c->{FCC_SELECTOR} = $f;
	#テンプレートディレクトリ
	$c->{TEMPLATE_DIR} = "$c->{BASE_DIR}/template/$c->{FCC_SELECTOR}";
	#処理モード取得
	my $m = $self->{q}->param('m');
	unless($m) {$m = "index";}
	$m = ucfirst $m;
	if($m =~ /^[^a-zA-Z0-9]/) {
		die 'Invalid Parameter.';
	}
	#認証処理
	my $session = new FCC::Class::SellerSession(conf=>$c, memd=>$memd, q=>$self->{q});
	my $session_data = $session->auth();
	if($m !~ /^(Athlinfrm|Athlinsmt)$/i) {
		unless($session_data) {
			$db->{dbh}->disconnect();
			my $cookie_list = $session->logoff_cookie_strings();
			for my $cookie_string (@{$cookie_list}) {
				print "Set-Cookie: ". $cookie_string . "\n";
			}
			print "Location: $c->{CGI_DIR_URL}/seller.cgi?m=athlinfrm\n\n";
			exit;
		}
	}
	#アクション（モデル）
	my $apm;
	if(-e "$c->{BASE_DIR}/lib/FCC/Action/${f}/${m}Action.pm") {
		$apm = "FCC::Action::${f}::${m}Action";
		eval qq(require $apm; import $apm);
		if($@) { die $@; }
	} elsif(-e "$c->{BASE_DIR}/lib/FCC/Action/${f}/DefaultAction.pm") {
		$apm = "FCC::Action::${f}::DefaultAction";
		eval qq(require $apm; import $apm);
		if($@) { die $@; }
	} else {
		$apm = "FCC::Action::DefaultAction";
		eval qq(require $apm; import $apm);
		if($@) { die $@; }
	}
	my $action = new $apm;
	$action->set('conf' ,$c);
	$action->set('q', $self->{q});
	$action->set('session', $session);
	$action->set('memd' ,$memd);
	$action->set('db', $db);
	my $context = $action->dispatch();
	#ビュー
	my $vpm;
	if(-e "$c->{BASE_DIR}/lib/FCC/View/${f}/${m}View.pm") {
		$vpm = "FCC::View::${f}::${m}View";
		eval qq(require $vpm; import $vpm);
		if($@) { die $@; }
	} elsif(-e "$c->{BASE_DIR}/lib/FCC/View/${f}/DefaultView.pm") {
		$vpm = "FCC::View::${f}::DefaultView";
		eval qq(require $vpm; import $vpm);
		if($@) { die $@; }
	} else {
		$vpm = "FCC::View::DefaultView";
		eval qq(require $vpm; import $vpm);
		if($@) { die $@; }
	}
	my $view = new $vpm;
	$view->set('conf' ,$c);
	$view->set('q', $self->{q});
	$view->set('session', $session);
	$view->set('memd' ,$memd);
	$view->set('db', $db);
	$view->dispatch($context);
	#DB切断
	$db->disconnect_db();
}

sub load_conf {
	my($self) = @_;
	my $c = {};
	while( my($k, $v) = each %{$self->{params}} ) {
		$c->{$k} = $v;
	}
	#デフォルト設定値を取得
	my $ct = Config::Tiny->read("$c->{BASE_DIR}/default/default.ini.cgi") or die "failed to read deafult configurations file '$c->{BASE_DIR}/default/default.ini.cgi'. : $!";
	while( my($k, $v) = each %{$ct->{default}} ) {
		$c->{$k} = $v;
	}
	return $c;
}

sub get_selector {
	my($self) = @_;
	if($self->{params}->{FCC_SELECTOR}) {
		return $self->{params}->{FCC_SELECTOR};
	} else {
		my($file, $dir, $ext) = File::Basename::fileparse( $self->{q}->url(-absolute=>1), qr/\..*/ );
		my $selector = ucfirst $file;
		return $selector;
	}
}

1;
