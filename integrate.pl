use strict;
use MIME::Base64;
use XML::LibXML;
use REST::Client;
use JSON;
use utf8;
use Encode;
use POSIX 'strftime';
use Net::IMAP::Simple;
use Net::SMTP::SSL;
use Mail::Header;
use MIME::Parser;
use MIME::Base64();
use File::Copy;
use FindBin '$RealBin';

# binmode STDOUT, ":utf8";
# use open ( ":encoding(UTF-8)", ":std" );

#get config 
my $config_path = $RealBin . '/conf.txt';
my %config = ();
open ( _FH, $config_path ) or die "Unable to open config file: $!";
 
while ( <_FH> ) {
    chomp;
    s/#.*//;                # ignore comments
    s/^\s+//;               # spaces
    s/\s+$//;               # spaces
    next unless length;
    my ($_configParam, $_paramValue) = split(/\s*=\s*/, $_, 2);
    $config{$_configParam} = $_paramValue;
}
close _FH;

my $send_flag = $config{send_flag};
my $mail_remove_flag = $config{mail_remove_flag};
my $mail_debug       = $config{mail_debug};

# SN creds:
my $host = $config{snhost};
my $user = $config{snuser};
my $pwd = $config{snpwd};

# каталог с xml
my $xmldir = $RealBin . '/xml/';
my $xml_out = $config{xml_out};;

my $date_string = strftime '%H:%M:%S-%d.%m.%Y', localtime;
my $logpath = $RealBin . "/log.txt";
my $xml_counter = 0;
my $xml_calls;
my $client = REST::Client->new( host => $host );
my $encoded_auth = encode_base64( "$user:$pwd", '' );

# Словарь статусов SN - XML
my %sn_status_hash = (
    '1'  => 'IN_PROGRESS',
    '10' => 'IN_PROGRESS',
    '16' => 'IN_PROGRESS',
    '17' => 'IN_PROGRESS',
    '18' => 'IN_PROGRESS',

    #REJECT
    '7' => 'DONE',

    #DONE
    '4' => 'DONE',
    '3' => 'DONE'
);

### Прием почты

# параметры почтового ящика
my $mailhost = $config{mailhost};
my $mailuser = $config{mailuser};
my $mailpass = $config{mailpass};
my $mailfolder =
  "INBOX";    # папка, в которой проверяем почту
my $mailNewFolder = "read"; # папка, в которую перекладываем прочтенные письма(создать)

# print_log( "INFO", "New RUN", $logpath);

# создаем подключение к серверу
my $imap = Net::IMAP::Simple->new(
    $mailhost,
    port    => 993,
    use_ssl => 1,
    debug   => 0,
) || die "Error! Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";
my @Content;

if ( !$imap->login( $mailuser, $mailpass ) ) {
    print STDERR "Error! Login failed: " . $imap->errstr . "\n";
    exit(64);
}

# Читаем входящие сообщения
my $nm = $imap->select($mailfolder);

# Последователь проходим по списку сообщений
for ( my $i = 1 ; $i <= $nm ; $i++ ) {

# Получаем список служебных заголовков письма
    my $header = $imap->top($i);

# Разбиваем заголовки на отдельные составляющие
    my $head_obj = Mail::Header->new($header);

# по теме письма формируем имя директории для сохранения вложений
    my $dir  = $head_obj->get('Subject');
    my $from = $head_obj->get('From:');

# удаляем все не словарные символы,
# для исключения проблем с созданием папок в windows
    $dir =~ s/\W+//g;

    print "Recieving mail $i - subject $dir - from $from";

    #=========================
    # Сохраняем текущее собщение в файл msg
    # open MSGFILE,"> msg" or die "Couldn't open file: \n";
    # print MSGFILE @{ $imap->get($i) };
    # close MSGFILE;

    # разбираем письмо на вложения
    my $parser = MIME::Parser->new();
    $parser->output_dir( $xmldir . 'in' );
    my $data = join( '', @{ $imap->get($i) } );

    # print $data;
    my $message = $parser->parse_data( \$data );
    my $body    = $message->as_string
      ; # Вытаскиваем из письма единственный файл
    $body =~ s/\n//g;    # Делаем скаляр однострочным
    $body =~ s/.*xml\"([\w]+).*/$1/g
      ; # Из письма извлекем xml, зашифрованный Base64
    $body = MIME::Base64::decode($body);
    Encode::from_to( $body, 'cp-1251', 'utf-8' );
    $body =~ s/.*(\n)(\d{7}\s.*)\n.*/$2/gs
      ; # Отбираем из многострочного(s) текста нужную строку - начинается с 7 цифр(от \n до \n)
    $body = $2
      ; # Присваиваем скаляру именно эту строку, иначе в нем окажется пустота

    foreach ($body) {
        @Content = split(' ')
          ; # Содержимое файла в отправили в массив
    }

# перемещаем сообщение в папку обработанных. если папка для перемещения не создана письмо будет только удалено
#$imap->copy($i,$mailNewFolder);
#removing message on mail.ru
    if ( $mail_remove_flag == 1 ) {
        $imap->delete($i);
    }
}

# Закрываем подключение к imap серверу
$imap->quit;

# Удаляем лишние файлы:
unlink glob "$xmldir" . 'in' . "/*.txt";
unlink glob "$xmldir" . 'in' . "/*.html";

### ЗАГРУЗКА XML в snow

# массив с номерами заявок от банка
my @call_array;

# открываем каждый пришедший xml файл, парсим, создаем новый WO если не создан, запоминаем по каким SB_ID надо ответить
my @inbound_xml_files = glob( "$xmldir" . 'in' . "/*.xml" );

if (@inbound_xml_files) {
    print "$date_string --- NEW RUN\n";
    foreach my $inbound_xml_file (@inbound_xml_files) {
        my $xml_file_size = -s $inbound_xml_file;
        print "----------- Processing $inbound_xml_file, size - $xml_file_size\n";
        if ( $xml_file_size > 0 ) {

            my $dom = XML::LibXML->load_xml( location => $inbound_xml_file );

#/CIM[@CIMVERSION="2.0"]/DECLARATION/DECLGROUP/VALUE.OBJECT//INSTANCE/PROPERTY[@NAME='СБ_ID']/VALUE
            foreach my $call (
                $dom->findnodes(
                  '/CIM[@CIMVERSION="2.0"]/DECLARATION/DECLGROUP/VALUE.OBJECT//INSTANCE'
                )
              )
            {
                my $classname =
                  Encode::encode_utf8( $call->findvalue('./@CLASSNAME') );

                # СБ_ID
                my $sb_id =
                  $call->findvalue('./PROPERTY[@NAME=\'СБ_ID\']/VALUE');

                # ШАБЛОН
                my $template = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ШАБЛОН\']/VALUE')
                );

                # ИДЕНТИФИКАТОР (Номер в SN)
                my $sn_id = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ИДЕНТИФИКАТОР\']/VALUE'
                    )
                );

                # ТЕМА
                my $short_descr = Encode::encode_utf8(
                    $call->findvalue('./PROPERTY[@NAME=\'ТЕМА\']/VALUE') );

                # ИНФОРМАЦИЯ
                my $descr = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ИНФОРМАЦИЯ\']/VALUE')
                );
                $descr =~ s/\"//g;    #ковычки ломают JSON
		$descr =~ s/\t//g;                      # ИНИЦИАТОР
                my $caller = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ИНИЦИАТОР\']/VALUE')
                );

                # ТЕЛЕФОН
                my $phone = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ТЕЛЕФОН\']/VALUE')
                );

                # ВРЕМЯ_РЕГИСТРАЦИИ
                my $reg_time = Encode::encode_utf8(
                    $call->findvalue(
                      './PROPERTY[@NAME=\'ВРЕМЯ_РЕГИСТРАЦИИ\']/VALUE'
                    )
                );

                # СРОК
                my $srok_time = Encode::encode_utf8(
                    $call->findvalue('./PROPERTY[@NAME=\'СРОК\']/VALUE') );

                # ЖЕЛАЕМАЯ_ДАТА
                my $desired_time = Encode::encode_utf8(
                    $call->findvalue(
                        './PROPERTY[@NAME=\'ЖЕЛАЕМАЯ_ДАТА\']/VALUE')
                );
                my $request_body =
                    "{\"description\":\""
                  . $descr
                  . "\",\"u_external_id\":\""
                  . $sb_id
                  . "\",\"short_description\":\""
                  . $short_descr
                  . "\",\"u_caller\":\""
                  . $caller
                  . "\",\"state\": \"10\",\"u_caller_phone\":\""
                  . $phone
                  . "\",\"u_glide_date_time_reg\":\""
                  . $reg_time
                  . "\",\"u_glide_date_time_srok\":\""
                  . $srok_time
                  . "\",\"u_glide_date_time_desired\":\""
                  . $desired_time
                  . "\",\"u_sberbank_template\":\""
                  . $template
                  . "\",\"work_notes\":\"\",\"location\":\"9fbd89294f383e0053e91aabb110c7a8\",\"sysparm_input_display_value\":\"true\"}";

                $request_body =~ s/\r\n/\\n/g;

                #if ($sb_id ~~ @call_array){}
                if ( grep /^$sb_id/, @call_array ) { }
                else {
                    push( @call_array, $sb_id );
                    print "Saving $sb_id id to form xml answer\n";
                }

                print "SB Call $sb_id has CLASSNAME $classname !\n";

                if ( $classname eq 'NEW' ) {

                    #check if exist and create WO if not
                    if ( rest_get($sb_id) == 1 ) {
                        print "Creating $sb_id in service now!!\n";
                        rest_post($request_body);
                    }
                }
                elsif ( $classname eq 'REJECT' ) {
                    my $sys = rest_get($sb_id);
                    my $request_body =
                      "{\"close_notes\":\"WO Cancelled!\",\"u_close_code\":\"8\"}";
                    if ( $sys != 1 ) {
                        print "sys_id - $sys!!\n";
                        rest_put( $request_body, $sys );
                        sleep(3);
                        rest_put( $request_body, $sys );
                    }
                    else {
                        print "No WO for rejection $sb_id\n";
                    }
                }
            }
		#      move( $inbound_xml_file, "$xmldir" . 'in/done' )
        #      or die "The move operation failed: $!";
	rename $inbound_xml_file, $inbound_xml_file . $date_string . ".xml";
        move( $inbound_xml_file . $date_string . ".xml", "$xmldir" . 'in/done' )
        or die "Error! The move operation failed: $!";

        }
        else {
            print "$inbound_xml_file is empty, ignoring...\n";
     #       move( $inbound_xml_file, "$xmldir" . 'in/done' )
     #         or die "The move operation failed: $!";
	rename $inbound_xml_file, $inbound_xml_file . $date_string . ".xml";
    	move( $inbound_xml_file . $date_string . ".xml", "$xmldir" . 'in/done' )
      	or die "Error! The move operation failed: $!";

        }
    }
}
else {
    #print "$date_string --- NEW RUN\n";
    #print "Looks like there is no mail\n";
    # print_log( "MAILINFO", "looks like there is no XML. No MAIL?", $logpath);
}

# создать новый WO
sub rest_post {
    my ($req) = @_;
    print "req - $req\n";
    $client->POST(
        "/api/now/table/wm_order",
        $req,
        {
            'Authorization' => "Basic $encoded_auth",
            'Content-Type'  => 'application/json;charset=UTF-8',
            'Accept'        => 'application/json'
        }
    );
    print 'Response: ' . $client->responseContent() . "\n";
    print 'Response status: ' . $client->responseCode() . "\n";
    

    #    foreach ( $client->responseHeaders() ) {
    #    print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
    #    }
}

#Модификация заявок, для отзыва из банка
sub rest_put {
    my ( $req, $sysid ) = @_;
    print "req - $req\n";
    $client->PUT(
        "/api/now/table/wm_order/$sysid",
        $req,
        {
            'Authorization' => "Basic $encoded_auth",
            'Content-Type'  => 'application/json;charset=UTF-8',
            'Accept'        => 'application/json'
        }
    );
    print 'Response: ' . $client->responseContent() . "\n";
    print 'Response status: ' . $client->responseCode() . "\n";

    #    foreach ( $client->responseHeaders() ) {
    #    print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
    #    }
}

# получить запись из SN по банковскому ID чтоб понять создавать ли новый WO
sub rest_get {
    my ($id) = @_;
    print "id in rest_get - $id\n";
    $client->GET(
        "/api/now/table/wm_order?sysparm_limit=1&u_external_id=" . $id,
        {
            'Authorization' => "Basic $encoded_auth",
            'Accept'        => 'application/xml'
        }
    );

    # print 'Response: ' . $client->responseContent() . "\n";
    my $restest = $client->responseContent();
    my $parser  = XML::LibXML->new();
    my $doc     = $parser->parse_string($restest);
    foreach my $call ( $doc->findnodes('/response') ) {
        my $wonumber =
          Encode::encode_utf8( $call->findvalue('./result/number') );
        my $state  = Encode::encode_utf8( $call->findvalue('./result/state') );
        my $sys_id = Encode::encode_utf8( $call->findvalue('./result/sys_id') );

        if ( $wonumber eq "" ) { return 1; }
        else {
            print "wo for $id exists - $wonumber and state $state and sysid $sys_id.... IGNORING creation for $id\n";
            return $sys_id;
        }
    }

    #   print 'Response status: ' . $client->responseCode() . "\n";

    # foreach ( $client->responseHeaders() ) {
    # print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
    # }
}

sub form_xml {
    my ( $sber_id, $wo_id, $state_code, $close_notes, $close_code ) = @_;
    $xml_counter++;
    my $classname = $sn_status_hash{$state_code};
    print "Forming xml... $sber_id/$wo_id - state code - $state_code - xmlStatus - $classname\n";
    my $instance_template = '<VALUE.OBJECT>
	<INSTANCE CLASSNAME="' . $classname . '">
	<PROPERTY NAME="ID" TYPE="string">
		<VALUE>' . $xml_counter . '</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СБ_ID" TYPE="string">
		<VALUE>' . $sber_id . '</VALUE>
	</PROPERTY>
	<PROPERTY NAME="ИДЕНТИФИКАТОР" TYPE="string">
		<VALUE>' . $wo_id . '</VALUE>
	</PROPERTY>
	';

    if ( ( $classname eq 'DONE' ) and ( $state_code ne '7' ) ) {
        $instance_template .= '	<PROPERTY NAME="РЕШЕНИЕ" TYPE="string">
		<VALUE>' . $close_notes . '</VALUE>
	</PROPERTY>
	<PROPERTY NAME="КОД_ЗАКРЫТИЯ" TYPE="string">
		<VALUE>' . $close_code . '</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СТАТУС" TYPE="string">
		<VALUE>2</VALUE>
	</PROPERTY>
	</INSTANCE>
</VALUE.OBJECT>';
    }

    #ответ на REJECT
    elsif ( ( $classname eq 'DONE' ) and ( $state_code eq '7' ) ) {
        $instance_template .=
'<PROPERTY NAME="РЕШЕНИЕ" TYPE="string">
		<VALUE>' . $close_notes . '</VALUE>
	</PROPERTY>
	<PROPERTY NAME="КОД_ЗАКРЫТИЯ" TYPE="string">
		<VALUE>8</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СТАТУС" TYPE="string">
		<VALUE>8</VALUE>
	</PROPERTY>
	</INSTANCE>
</VALUE.OBJECT>';
    }
    else {
        $instance_template .=
'	</INSTANCE>
</VALUE.OBJECT>';
    }

    #$instance_template = Encode::encode_utf8($instance_template);
    # print $instance_template;
    return $instance_template;

}

sub print_log {
    my ( $type, $message, $logpath_var ) = @_;
    my $log_date_string = strftime '%H:%M:%S-%d.%m.%Y', localtime;
    open( OUT, ">$logpath_var" );
    binmode( OUT, ":utf8" );
    print OUT $type . " --- ". $log_date_string . " --- " . $message . "\n";
    close OUT;
}

### СОЗДАНИЕ XML

my $xml_start = '<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE CIM PUBLIC "SYSTEM" "CIM_DTD_V20.dtd"[
<!ENTITY lt      "&#38;#60;">
<!ENTITY gt      "&#62;">
<!ENTITY amp     "&#38;#38;">
<!ENTITY apos    "&#39;">
<!ENTITY quot    "&#34;">]>
<CIM CIMVERSION="2.0" DTDVERSION="2.2">
<DECLARATION>
<DECLGROUP>
<VALUE.OBJECT>
<INSTANCE CLASSNAME="Header">
<PROPERTY NAME="Date" TYPE="string">
	<VALUE>' . "$date_string" . '</VALUE>
</PROPERTY>
<PROPERTY NAME="Application" TYPE="string">
	<VALUE>ServiceNow TMC</VALUE>
</PROPERTY>
</INSTANCE>
</VALUE.OBJECT>';

my $xml_end = '
</DECLGROUP>
</DECLARATION>
</CIM>';

# Формировка xml для каждого пришедшего из банка id

foreach my $call (@call_array) {
    chomp $call;

    $client->GET(
        "/api/now/table/wm_order?sysparm_limit=1&u_external_id=" . $call,
        {
            'Authorization' => "Basic $encoded_auth",
            'Accept'        => 'application/xml'
        }
    );

    # print 'Response: ' . $client->responseContent() . "\n";
    my $restest = $client->responseContent();
    my $parser  = XML::LibXML->new();
    my $doc     = $parser->parse_string($restest);
    foreach my $call_record ( $doc->findnodes('/response') ) {
        my $wonumber =
          Encode::encode_utf8( $call_record->findvalue('./result/number') );
        my $state =
          Encode::encode_utf8( $call_record->findvalue('./result/state') );
        my $close_code = Encode::encode_utf8(
            $call_record->findvalue('./result/u_close_code') );
        my $close_notes = $call_record->findvalue('./result/close_notes');

        # print "data - ".$wonumber." ".$call." ".$state;

        $xml_calls .=
          form_xml( $call, $wonumber, $state, $close_notes, $close_code );

    }

    # print 'Checking WO '. $call .' status: ' . $client->responseCode() . "\n";

    # foreach ( $client->responseHeaders() ) {
    # print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
    # }

}

# Сохраняем финальный xml текст в файл ->

if ( $send_flag == 1 ) {

    my $final_xml = $xml_start . $xml_calls . $xml_end;
    my $xml_out_path   = $xmldir . 'out/' . $xml_out;
    open( OUT, ">$xml_out_path" );
    binmode( OUT, ":utf8" );
    print OUT $final_xml;
    close OUT;

### Отправка письма в банк

    my $attachTextFile     = $xmldir . 'out/' . $xml_out;
    open( DAT, $attachTextFile ) || die("Error! Could not open text file!");
    my @textFile = <DAT>;
    close(DAT);

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
    $smtp->to( 'eso@sberbank.ru' . "\n" );

    #$smtp->to( 'may.viktor@gmail.com' . "\n" );
    # Непосредственно передача данных
    $smtp->data();

#$smtp->datasend("List-Unsubscribe: " . '<mailto:may.viktor@gmail.com>' . "\n");
    $smtp->datasend( "From: " . 'integration.oktava@mail.ru' . "\n" );
    $smtp->datasend( "Subject: " . 'Sber-Oktava' );
    $smtp->datasend("\n");
    $smtp->datasend("Content-Type: application/text; name=\"$xml_out\"\n");
    $smtp->datasend("Content-Disposition: attachment; filename=\"$xml_out\"\n");
    $smtp->datasend("\n");
    $smtp->datasend("@textFile\n");
    $smtp->dataend();

    #print "mail sent!\n";

    # Закрываем сокет соединения с сервером
    $smtp->quit;

    # перемещение отправленного xml в out/done
    rename $attachTextFile, $attachTextFile . $date_string . ".xml";
    move( $attachTextFile . $date_string . ".xml", "$xmldir" . 'out/done' )
      or die "Error! The move operation failed: $!";
}
else { print "Turn on mail sending! Change send_flag to 1\n"; }
