use Net::SMTP::SSL;
use FindBin '$RealBin';
use Mail::Header;
use MIME::Base64;
my $logpath = $RealBin . "/log.txt";

my $alarmPeriod = 40; #minutes

my $mtime = (stat($logpath))[9];            
my $currentTime = time;
my $diff = ($currentTime - $mtime)/60;

if ($diff > $alarmPeriod) {
	print "sending mail. diff is $diff\n";
	sendMail("Logfile $logpath has not been updated for $alarmPeriod minutes");
}
else {
	print "file is ok - $diff";
}

my $lineLimit = 30;
open my $f, '<', $logpath or die;
my @lines;
$#lines = $limit;
while( <$f> ) {
  shift @lines if @lines >= $lineLimit;
  push @lines, $_
}
#print @lines;

if ( grep( /Error/, @lines ) ) {
  print "found error\n";
  sendMail("Logfile $logpath contains errors! Last $lineLimit lines: @lines");
}

#if ( grep( /Looks/, @lines ) ) {
#  print "found no mail\n";
#  sendMail("No mail for 10 minutes! Last $lineLimit lines: @lines");
#}


sub sendMail {
    my ( $message ) = @_;
     my $smtp = Net::SMTP::SSL->new(
        'smtp.mail.ru',
        Port  => 465,
        Debug => $mail_debug
    );

    $smtp->datasend("AUTH LOGIN\n");
    $smtp->response();
    $smtp->datasend( encode_base64('') );    # username
    $smtp->response();
    $smtp->datasend( encode_base64('') );          # password
    $smtp->response();

# $smtp->auth('integration.servicenow', 'asdfzxcv1234'); #так не работает

    # Создаем письмо
    $smtp->mail( 'integration.oktava@mail.ru' . "\n" );

    # Указываем кому направляется письмо
    $smtp->to( 'may.viktor@gmail.com' . "\n" );
    # Непосредственно передача данных
    $smtp->data();

#$smtp->datasend("List-Unsubscribe: " . '<mailto:may.viktor@gmail.com>' . "\n");
    $smtp->datasend( "From: " . 'integration.oktava@mail.ru' . "\n" );
    $smtp->datasend( "Subject: " . 'Alarm!' );
    $smtp->datasend("\n");
    # $smtp->datasend("Content-Type: application/text; name=\"$attachTextFileName\"\n");
    # $smtp->datasend("Content-Disposition: attachment; filename=\"$attachTextFileName\"\n");
    # $smtp->datasend("\n");
    # $smtp->datasend("@textFile\n");
    $smtp->datasend("$message\n");
    $smtp->dataend();

    print "mail sent!\n";

    # Закрываем сокет соединения с сервером
    $smtp->quit;
}

#large log cleanup
my $logSize = -s $logpath;
if ($logSize > 1000000) {
    unlink $logpath or warn "Could not unlink: $!";
}
