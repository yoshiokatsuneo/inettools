#!/usr/local/bin/perl
use Socket;
sub usage
{
	print "usage: deletemail [host] [port] [num]\n";
}
if($0 eq __FILE__){
#	$thishost = $ARGV[0] || "sgi052";
	if(@ARGV != 3){usage();exit(1);}
	$host = $ARGV[0] || 'mailserver';	
	$port = $ARGV[1] || 110;
	$deletenum = $ARGV[2] || 0;
	socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	bind(SH,sockaddr_in(0,inet_aton($thishost))) || die "bind:$!";
	print "binded\n";
	connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
	print "connected\n";
	$oldfh = select(SH);$|=1;select($oldfh);
	print SH "USER XXXXXX\r\n";
	sleep(1);
	print SH "PASS XXXXXX\r\n";
	sleep(1);
	#print SH "LIST\r\n";
	#sleep(1);
	print SH "STAT\r\n";
	sleep(1);
	for($i=1;$i<=$deletenum;$i++){
		print "DELE $i\r\n";
		print SH "DELE $i\r\n";
	}
	sleep(1);
	print SH "STAT\r\n";
	sleep(1);
	print SH "QUIT\r\n";
	sleep(1);
	# select((select(SH),$|=1)[0]);
	while(<SH>){
		print;
	}
	close(SH);
	#while(<STDIN>){
	#	print SH $_;
	#}	
	#close(SH);
}

