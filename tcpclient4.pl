#!/usr/local/bin/perl
use Socket;
if($0 eq __FILE__){
	$thishost = $ARGV[0] || "sgi052";	
	$port = $ARGV[1] || 12345;
	$host = $ARGV[2] || 'localhost';	
	socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	bind(SH,sockaddr_in(0,inet_aton($thishost))) || die "bind:$!";
	print "binded\n";
	connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
	print "connected\n";
	select((select(SH),$|=1)[0]);	
	while(<STDIN>){
		print SH $_;
	}	
	close(SH);
}

