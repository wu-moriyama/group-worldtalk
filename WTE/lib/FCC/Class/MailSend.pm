#
# MailSend.pm, 2008/02/17, mukairiku
#
# Copyright (c) 2008 mukairiku
# All rights reserved.
# http://www.mukairiku.net/
#
package MailSend;

use strict;
use warnings;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.01;
@ISA = qw(Exporter);

@EXPORT      = qw(MailSend);
@EXPORT_OK   = qw();
%EXPORT_TAGS = ();

use Net::SMTP;
use MIME::Entity;
use Jcode;

###########################################################
# MailSend(\%data)                                        #
#  メールを送信します。                                   #
###########################################################
sub MailSend{
  my $data = shift;
  
  my $To      = $data->{'To'};
  my $From    = $data->{'From'};
  my $Subject = $data->{'Subject'};
  my $Msg     = $data->{'Msg'};
  my $Server  = $data->{'Server'};
  my $User    = $data->{'User'};
  my $Pass    = $data->{'Pass'};
  my $Attach  = $data->{'Attach'};
  
  # 引数の中身を一応チェック
  return(0) if !defined($To);
  return(0) if !defined($From);
  return(0) if !defined($Server);
  $Subject = "No Subject" if !defined($Subject);
  $Msg     = "No Message" if !defined($Msg);
  
  # あれこれエンコード
  Jcode::convert(\$Msg,  "jis");           # 本文をJISにエンコード
  $To      = jcode($To)->mime_encode;      # ToをBase64エンコード
  $From    = jcode($From)->mime_encode;    # FromをBase64エンコード
  $Subject = jcode($Subject)->mime_encode; # 件名をBase64エンコード
  
  # メールデータの作成
  my $mime = MIME::Entity->build( To       => $To,  
                                  From     => $From, 
                                  Subject  => $Subject, 
#                                  Type     => 'text/plain;charset="iso-2022-jp"', 
                                  Data     => $Msg, 
                                  Encoding => "7bit", 
                                );
  
  my @files = ();
  @files = split(/,/, $Attach) if defined($Attach);
  
  for my $file (@files){
    my $Path     = $file;
    my $filename = $file;
    $filename =~ s/\\/\//g;
    my @parts = split(/\//, $filename);
    $filename = pop(@parts);
    
    $mime->attach( Path     => $Path, 
                   Filename => jcode($filename)->mime_encode, 
                   Type     => "Application/octet-stream", 
                   Encoding => "Base64"
                 );
  }
  
  # メール送信
  my $smtp = Net::SMTP->new($Server, 
                            'Hello'   => $Server, 
                            'Timeout' => 60) || return (0);
  
  # ユーザー名とパスワードが設定されていれば、認証を行う
  if(defined($User) && defined($Pass)){
    $smtp->auth($User, $Pass);
  }
  
  $smtp->mail($From);
  $smtp->to($To);
  
  $smtp->data();
  $smtp->datasend($mime->stringify);
  $smtp->dataend();
  $smtp->quit || return 0;
  return 1;
}

1;
