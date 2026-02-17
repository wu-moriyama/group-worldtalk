#---------------------------------------------------------------------#
#■メール送信モジュール
#
#・使い方
#
#	my $mail = new FCC::Class::Mail::Sendmail(
#		sendmail => '/usr/sbin/sendmail',
#		body => $body,
# 		hdrs => {
# 			To => 'hoge@futomi.com',
#			Cc => 'cc@futomi.com',
#			Bcc => 'bcc@futomi.com',
# 			From => 'dummy@futomi.com',
# 			Error-To => 'error@futomi.com',
# 			Subject => 'サブジェクト',
#			Date => 'Sat, 12 Jan 2008 14:46:34 +0900'
# 		},
#		attachments => [ {...}, {...}, ... ],
#		tmp_dir => '/tmp'
# 	);
#
#	# または
#
#	my $mail = new FCC::Class::Mail::Sendmail(
#		sendmail => '/usr/sbin/sendmail',
#		eml => $eml,
#		tz => 'Asia/Tokyo'
# 	);
#
#	#SMTPサーバを指定する場合
#
# 	my $mail = new FCC::Class::Mail::Sendmail(
# 		smtp_host => $self->{conf}->{smtp_host},
# 		smtp_port => $self->{conf}->{smtp_port},
# 		smtp_auth_user => $self->{conf}->{smtp_auth_user},
# 		smtp_auth_pass => $self->{conf}->{smtp_auth_pass},
# 		smtp_timeout => $self->{conf}->{smtp_timeout},
#		body => $body,
# 		hdrs => {
# 			To => 'hoge@futomi.com',
#			Cc => 'cc@futomi.com',
#			Bcc => 'bcc@futomi.com',
# 			From => 'dummy@futomi.com',
# 			Error-To => 'error@futomi.com',
# 			Subject => 'サブジェクト',
#			Date => 'Sat, 12 Jan 2008 14:46:34 +0900'
# 		},
#		attachments => [ {...}, {...}, ... ],
#		tmp_dir => '/tmp'
# 	);
#
#	# メール送信
# 	$mail->mailsend();
# 	if( my $error = $mail->error() ) {
# 		$context->{fatalerrs} = [$error];
# 	}
#
#	コンストラクタ生成時に与える引数のうち、sendmail、body、hdrsは必須。
#	emlを与えた場合、hdrsは無視される。
#	emlは、次のようなフォーマットでなければいけない。
#
#	------------------------------------
#	To: hoge@futomi.com
#	From: dummy@futomi.com
#	Subject: サブジェクト
#	
#	本文・・・・・・
#	------------------------------------
#
#	To, From, Subjectは必須。その他、Cc, Bcc, Dateを指定できる。
#
#	hdrsは、無名ハッシュとして定義する。このうち、to、from、subjectは
#	必須。errortoはオプションだが、指定がないと、sendmailの-fオプショ
#	ンに、fromで指定されたメールアドレスがセットされる。
#
#	attachmentsは、添付ファイル情報を格納したhashrefのarrayrefとすること。
#	[
#		{
#			filename => ファイル名（必須）,
#			path     => ファイル格納パス（必須）,
#			mtype    => MIMEタイプ（任意）
#		},
#		...
#	]
#
#	attachemntsを指定した場合は、tmp_dirは必須。
#	もしtmp_dirが指定されていなければ . （カレントディレクトリ）となる。
#---------------------------------------------------------------------#

package FCC::Class::Mail::Sendmail;
$VERSION = 1.01;
use strict;
use warnings;
use Carp;
use Mail::SendEasy;
use MIME::Base64::Perl;
use MIME::QuotedPrint::Perl;
use MIME::Types;
use Data::Random::String;
use Unicode::Japanese;
use File::Which;
use File::Read;
use FCC::Class::String::Checker;
use FCC::Class::Date::Utils;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	$self->{sendmail} = $args{sendmail};
	$self->{smtp_host} = $args{smtp_host};
	$self->{smtp_port} = $args{smtp_port};
	$self->{smtp_auth_user} = $args{smtp_auth_user};
	$self->{smtp_auth_pass} = $args{smtp_auth_pass};
	$self->{smtp_timeout} = $args{smtp_timeout};
	$self->{hdrs} = $args{hdrs};
	$self->{body} = $args{body};
	$self->{eml} = $args{eml};
	$self->{tz} = $args{tz};
	$self->{attachments} = $args{attachments};
	$self->{tmp_dir} = $args{tmp_dir};
	#
	unless($self->{smtp_timeout}) {
		$self->{smtp_timeout} = 60;
	}
	#
	if( $self->{smtp_host} ) {
		if( ! defined $self->{smtp_port} || $self->{smtp_port} eq "" ) {
			$self->{smtp_port} = 25;
		}
		if( $self->{smtp_port} =~ /[^\d]/ ) {
			croak "smtp_port is invalid.";
		}
	}
	#添付ファイルの存在をチェック
	if( defined $self->{attachments} ) {
		if( ref($self->{attachments}) ne "ARRAY" ) {
			croak "attachments augument must be a arryaref.";
		}
		for my $hashref (@{$self->{attachments}}) {
			if( ref($hashref) ne "HASH" ) {
				croak "attachments augument must include hash refs as a array element.";
			}
			if( ! defined $hashref->{filename} ) {
				croak "elements in attachments augument must be a hash ref including filename property.";
			}
			if( ! defined $hashref->{path} ) {
				croak "elements in attachments augument must be a hash ref including path property.";
			}
			if( ! -f $hashref->{path} ) {
				croak "$hashref->{path} is not found.";
			}
		}
		if( defined $self->{tmp_dir} ) {
			$self->{tmp_dir} =~ s|/+$||;
		}
		if( ! defined $self->{tmp_dir} || $self->{tmp_dir} eq "" ) {
			$self->{tmp_dir} = ".";
		}
		if( $self->{tmp_dir} && ! -d $self->{tmp_dir} ) {
			croak "$self->{tmp_dir} is not a directory.";
		}
		my $tmp_file = "$self->{tmp_dir}/sendmail.body.tmp." . $$ . "." . time. ".cgi";
		if( open my $fh, ">", $tmp_file ) {
			close($fh);
			$self->{tmp_file} = $tmp_file;
		} else {
			croak "failed to open $tmp_file : $!";
		}
		unless( @{$self->{attachments}} ) {
			$self->{attachments} = undef;
		}
	}
	#
	$self->{error} = '';
	bless $self, $class;
	return $self;
}

sub mailsend {
	my($self) = @_;
	my $RN = "\015\012";
	#sendmailパス
	my $sendmail = $self->{sendmail};
	if($self->{smtp_host} && $self->{smtp_port}) {
	
	} else {
		unless($sendmail) {
			my @paths = File::Which::which('sendmail');
			$sendmail = $paths[0];
			$self->{sendmail} = $sendmail;
		}
		unless(-e $sendmail) {
			$self->{error} = "failed to find sendmail path.";
			return;
		}
	}
	#ヘッダー、ボディーを取得
	my %headers;
	my $body = "";
	if($self->{eml}) {
		my $eml = $self->{eml};
		$eml =~ s/${RN}/\n/g;
		my @eml_parts = split(/\n\n/, $eml);
		my $hdr = shift @eml_parts;
		$body = join("\n\n", @eml_parts);
		my @hdr_parts = split(/\n/, $hdr);
		for my $part (@hdr_parts) {
			my($k, $v) = $part =~ /^\s*([^\s\:]+)\s*\:\s*(.*)/;
			if($k && $v) {
				$headers{$k} = $v;
			}
		}
	} else {
		%headers = %{$self->{hdrs}};
		$body = $self->{body};
	}
	#ヘッダーの評価
	unless($headers{To} && $headers{From} && $headers{Subject}) {
		$self->{error} = "To, From, Subject is required.";
		return;
	}
	#サブジェクトと差出人のエンコードを特定する
	my $hdrs_encoding_test = $headers{Subject};
	if(defined $headers{Sender}) {
		$hdrs_encoding_test .= $headers{Sender};
	}
	my $hdrs_encoding = $self->_determine_encoding($hdrs_encoding_test);
	#サブジェクトをエンコードする
	$headers{Subject} = $self->_encode_subject($headers{Subject}, $hdrs_encoding);
	#差出人があれば、From行もエンコードする
	my $from = $headers{From};
	if($headers{Sender}) {
		$headers{From} = $self->_encode_from($headers{Sender}, $headers{From}, $hdrs_encoding);
	}
	#送信日時
	if( ! exists $headers{Date} && defined $self->{tz} && $self->{tz} ne "" ) {
		my @mon_map = ('', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
		my @week_map = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
		my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{tz})->get(1);
		$headers{Date} = "$week_map[$tm[6]], $tm[2] $mon_map[$tm[1]+0] $tm[0] $tm[3]:$tm[4]:$tm[5] $tm[8]";
	}
	#本文のエンコードを特定する
	my $encoding = $self->_determine_encoding($body);
	#本文の文字コード変換
	if($encoding eq 'iso-2022-jp') {
		#ISO-2022-JPに変換（実際にはJIS）
		$body = Unicode::Japanese->new($body)->jis;
	} elsif($encoding eq "utf-8") {
		#UTF-8の場合
		#本文をbase64エンコード
		$body = MIME::Base64::Perl::encode_base64($body);
	} else {
		Encode::from_to($body, "utf-8", $encoding);
	}
	#error-to
	my $errorto = $from;
	if($headers{"Error-To"}) {
		$errorto = $headers{"Error-To"};
	}
	#ヘッダー部生成
	my $hdr;
	while( my($k, $v) = each %headers ) {
		if( ! defined $v || $v eq "") { next; }
		if($k =~ /^Sender$/i) { next; }
		$hdr .= "${k}: ${v}\n";
	}
	$hdr .= "Mime-Version: 1.0\n";
	my $boundary;
	if( defined $self->{attachments} ) {
		# MIME Multipart用の境界を生成
		$boundary = $self->generate_multipart_boundary();
		$hdr .= "Content-Type: multipart/mixed;\n";
		$hdr .= " boundary=\"${boundary}\"\n";
	} else {
		if($encoding eq 'iso-2022-jp') {
			$hdr .= "Content-Type: text/plain; charset=iso-2022-jp\n";
			$hdr .= "Content-Transfer-Encoding: 7bit\n";
		} elsif($encoding eq "utf-8") {
			$hdr .= "Content-Type: text/plain; charset=utf-8; format=flowed\n";
			$hdr .= "Content-Transfer-Encoding: base64\n";
		} else {
			$hdr .= "Content-Type: text/plain; charset=${encoding}\n";
			$hdr .= "Content-Transfer-Encoding: quoted-printable\n";
		}
		$hdr .= "Content-Disposition: inline\n";
	}
	#ボディー部生成
	my $bdy;
	if( defined $self->{attachments} ) {
		open my $fh, ">", $self->{tmp_file};
		#テキスト部
		print $fh "--${boundary}\n";
		if($encoding eq 'iso-2022-jp') {
			print $fh "Content-Type: text/plain; charset=iso-2022-jp\n";
			print $fh "Content-Transfer-Encoding: 7bit\n";
		} elsif($encoding eq "utf-8") {
			print $fh "Content-Type: text/plain; charset=utf-8; format=flowed\n";
			print $fh "Content-Transfer-Encoding: base64\n";
		} else {
			print $fh "Content-Type: text/plain; charset=${encoding}\n";
			print $fh "Content-Transfer-Encoding: quoted-printable\n";
		}
		print $fh "Content-Disposition: inline\n";
		print $fh "\n";
		print $fh "${body}\n";
		print $fh "\n";
		#添付ファイル部
		for my $ref (@{$self->{attachments}}) {
			my $filename = $ref->{filename};
			my $path = $ref->{path};
			my $mtype = $ref->{mtype};
			if( ! defined $mtype || $mtype eq "" ) {
				$mtype = MIME::Types->new()->mimeTypeOf($filename);
			}
			if( ! defined $mtype || $mtype eq "" ) {
				$mtype = "application/octet-stream";
			}
			my $filename_encoded = $self->_encode_subject($filename);
			print $fh "--${boundary}\n";
			print $fh "Content-Type: ${mtype};\n";
			print $fh " name=\"${filename_encoded}\"\n";
			print $fh "Content-Transfer-Encoding: base64\n";
			print $fh "Content-Disposition: attachment;\n";
			print $fh " filename=\"${filename_encoded}\"\n";
			print $fh "\n";
			#添付ファイルをbase64エンコード
			my $file_data = File::Read::read_file($path);
			print $fh MIME::Base64::Perl::encode_base64($file_data);
			#print $fh "\n";
		}
		print $fh "--${boundary}--\n";
		close($fh);
	} else {
		$bdy = $body;
	}
	#メール送信
	if($sendmail) {
		if( open(SENDMAIL, "|${sendmail} -t -oi -f ${errorto}") ) {
			print SENDMAIL $hdr;
			print SENDMAIL "\n";
			if( defined $self->{attachments} ) {
				if( open my $fh, "<", $self->{tmp_file} ) {
					while( my $line = <$fh> ) {
						print SENDMAIL $line;
					}
					close($fh);
				} else {
					$self->{error} = "failed to open $self->{tmp_file} : $!";
					if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
					return;
				}
			} else {
				print SENDMAIL $bdy;
			}
			close(SENDMAIL);
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return 1;
		} else {
			$self->{error} = "failed to send a mail. : $!";
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return;
		}
	} else {
		my $smtp;
		if($self->{smtp_auth_user} && $self->{smtp_auth_pass}) {
			$smtp = Mail::SendEasy::SMTP->new($self->{smtp_host}, $self->{smtp_port} , $self->{smtp_timeout}, $self->{smtp_auth_user}, $self->{smtp_auth_pass}) ;
			if( ! $smtp ) {
				$self->{error} = "failed to connect to the smtp server.(1): $@";
			}
			if( ! $self->{error} &&  ! $smtp->auth ) {
				$self->{error} = "failed to pass smtp auth.(2): " . $smtp->last_response_line;
			}
		} else {
			$smtp = Mail::SendEasy::SMTP->new($self->{smtp_host}, $self->{smtp_port} , $self->{smtp_timeout}) ;
			if( ! $smtp ) {
				$self->{error} = "failed to connect to the smtp server.(3):  $@";
			}
		}
		unless($smtp) {
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return;
		}
		if ( $smtp->MAIL("FROM:<${errorto}>") !~ /^2/ ) {
			$self->{error} = "failed to send a mail. (4): " . $smtp->last_response_line;
			$smtp->close;
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return;
		}
		my @to_list;
		for my $k ('To', 'Cc', 'Bcc') {
			if( ! defined $headers{$k} || $headers{$k} eq "" ) { next; }
			my @parts = split(/\s*,\s*/, $headers{$k});
			for my $to (@parts) {
				if($to) { push(@to_list, $to); }
			}
		}
		for my $to (@to_list) {
			if( $smtp->RCPT("TO:<${to}>") !~ /^2/ ) {
			$self->{error} = "failed to send a mail.(5): " . $smtp->last_response_line;
				$smtp->close;
				if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
				return;
			}
		}
		if( $smtp->DATA =~ /^3/ ) {
			$hdr =~ s/${RN}/\n/g;
			$hdr =~ s/\n/${RN}/g;
			$smtp->print($hdr);
			$smtp->print($RN);
			if( defined $self->{attachments} ) {
				if( open my $fh, "<", $self->{tmp_file} ) {
					while( my $line = <$fh> ) {
						chomp $line;
						$line .= $RN;
						$smtp->print($line);
					}
					close($fh);
				} else {
					$self->{error} = "failed to open $self->{tmp_file} : $!";
					if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
					return;
				}
			} else {
				$body =~ s/${RN}/\n/g;
				$body =~ s/\n/${RN}/g;
				$smtp->print($bdy);
			}
			$smtp->print($RN);
			if ( $smtp->DATAEND !~ /^2/ ) {
				$self->{error} = "failed to send a mail. (6): " . $smtp->last_response_line;
				$smtp->close;
				if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
				return;
			}
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return 1;
		} else {
			$self->{error} = "failed to send a mail.(7):  " . $smtp->last_response_line;
			$smtp->close;
			if($self->{tmp_file} && -f $self->{tmp_file}) { unlink $self->{tmp_file}; }
			return;
		}
		$smtp->close;
	}
}

sub error {
	my($self) = @_;
	return $self->{error};
}

######################################################################

sub _encode_subject {
	my($self, $str, $encoding) = @_;
	if($str =~ /^[\x20-\x7e]+$/) {
		return $str;
	}
	if( ! $encoding ) {
		$encoding = $self->_determine_encoding($str);
	}
	my @chars = FCC::Class::String::Checker->new($str, 'utf8')->split_to_chars();
	if($encoding eq "iso-2022-jp") {
		my @lines;
		while( @chars ) {
			my @shifts = splice(@chars, 0, 20);
			my $line = join("", @shifts);
			$line = Unicode::Japanese->new($line)->jis;
			push(@lines, $line);
		}
		my @encoded_lines;
		for my $line (@lines) {
			my $encoded_line = MIME::Base64::Perl::encode_base64($line, "");
			push(@encoded_lines, "=?ISO-2022-JP?B?${encoded_line}?=");
		}
		return join("\n ", @encoded_lines);
	} elsif($encoding eq "utf-8") {
		my @lines;
		while( @chars ) {
			my @shifts = splice(@chars, 0, 15);
			my $line = join("", @shifts);
			push(@lines, $line);
		}
		my @encoded_lines;
		for my $line (@lines) {
			my $encoded_line = MIME::Base64::Perl::encode_base64($line, "");
			push(@encoded_lines, "=?UTF-8?B?${encoded_line}?=");
		}
		return join("\n ", @encoded_lines);
	} elsif($encoding eq "iso-8859-1") {
		require Encode;
		my @lines;
		while( @chars ) {
			my @shifts = splice(@chars, 0, 30);
			my $line = join("", @shifts);
			Encode::from_to($line, "utf-8", $encoding);
			push(@lines, $line);
		}
		my @encoded_lines;
		for my $line (@lines) {
			my $encoded_line = MIME::QuotedPrint::Perl::encode_qp($line, "");
			push(@encoded_lines, "=?ISO-8859-1?Q?${encoded_line}?=");
		}
		return join("\n ", @encoded_lines);
	} else {
		my @lines;
		while( @chars ) {
			my @shifts = splice(@chars, 0, 20);
			my $line = join("", @shifts);
			Encode::from_to($line, "utf-8", $encoding);
			push(@lines, $line);
		}
		my @encoded_lines;
		for my $line (@lines) {
			my $encoded_line = MIME::Base64::Perl::encode_base64($line, "");
			my $enq = uc $encoding;
			push(@encoded_lines, "=?${enq}?B?${encoded_line}?=");
		}
		return join("\n ", @encoded_lines);
	}
}

sub _determine_encoding {
	my($self, $str) = @_;
	if( ! defined $str ) { $str = ""; }
	my @supported;
	eval { require Encode; };
	if( ! $@ ) {
		@supported = Encode->encodings(":all");
	}
	# ASCII文字を除外
	$str =~ s/\x09|\x0a|\x0d|[\x20-\x7e]//g;
	# ASCII文字のみの場合
	if($str eq "") {
		my $enq = "iso-8859-1";
		if( my $n = grep(/^\Q${enq}\E$/, @supported) ) {
			return $enq;
		} else {
			return "utf-8";
		}
	}
	#Shift_JISに変換してみて、すべての文字が変換できればISO-2022-JP
	{
		my $n1 = $str =~ s/(\&\#\d{2,6}\;)/$1/g;
		my $sjis = Unicode::Japanese->new($str, "utf8")->sjis();
		my $n2 = $sjis =~ s/(\&\#\d{2,6}\;)/$1/g;
		if($n2 == $n1) {
			return "iso-2022-jp";
		}
	}
	# Latin Basic -> ISO-8859-1
	if($str =~ /^(\xc2[\xa0-\xbf]|\xc3[\x80-\xbf])+$/o) {
		my $enq = "iso-8859-1";
		if( my $n = grep(/^\Q${enq}\E$/, @supported) ) {
			return $enq;
		} else {
			return "utf-8";
		}
	}
	# Latin Extended-A -> ISO-8859-2
	if($str =~ /^([\xc4-\xc5][\x80-\xbf])+$/o) {
		my $enq = "iso-8859-2";
		if( my $n = grep(/^\Q${enq}\E$/, @supported) ) {
			return $enq;
		} else {
			return "utf-8";
		}
	}
	# Latin Extended-B -> ISO-8859-3
	if($str =~ /^([\xc6-\xc9][\x80-\xbf])+$/o) {;
		my $enq = "iso-8859-3";
		if( my $n = grep(/^\Q${enq}\E$/, @supported) ) {
			return $enq;
		} else {
			return "utf-8";
		}
	}
	#
	return "utf-8";
}

# From行をエンコード
sub _encode_from {
	my($self, $str, $from_addr, $encoding) = @_;
	my $enc_str = $self->_encode_subject($str, $encoding);
	if($enc_str =~ /^[\x20-\x7e]+$/) {
		$enc_str = "\"${enc_str}\"";
	}
	my @lines = split(/\n/, $enc_str);
	my $tmp = pop(@lines);
	if(length($tmp) + length($from_addr) + 3 > 75) {
		$enc_str .= "\n";
	}
	$enc_str .= " <${from_addr}>";
	return $enc_str;
}

# MIME Multipart用の境界を生成
sub generate_multipart_boundary {
	my($self) = @_;
	return "----=_Part_" . Data::Random::String->create_random_string(length=>'32', contains=>'alphanumeric') . "." . time;
}


1;
