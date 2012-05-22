#!/usr/local/bin/perl
use Socket;
if($0 eq __FILE__){
	$port = $ARGV[0] || 12345;
	$host = $ARGV[1] || 'localhost';	
	socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
	select((select(SH),$|=1)[0]);	
	while(<STDIN>){
		print SH $_;
	}	
	close(SH);
}

