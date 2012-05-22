#!/usr/local/bin/perl
use Socket;
if($0 eq __FILE__){
    $port = $ARGV[0] || 12345;shift;
    $host = $ARGV[0] || localhost;shift;	
    socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
    connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
    select((select(SH),$|=1)[0]);	
   
    $cmd.= "GET / HTTP/1.0\r\n";
    $cmd.= "Connection: Keep-Alive\r\n";
    $cmd.= "\r\n";
    $cmd.= "GET / HTTP/1.0\r\n";
    $cmd.= "\r\n";
    syswrite(SH,$cmd,length($cmd));
    while(<SH>){
	print;
    }
    close(SH);
}

