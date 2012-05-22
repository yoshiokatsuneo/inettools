#!/usr/bin/perl

use Socket;

#----------------MAIN-------------------
if($0 eq __FILE__){
	$port = ($ARGV[0] || 12345);
	socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
	bind(SH,sockaddr_in($port,INADDR_ANY)) 	|| die "cant bind to me:$!";
	# listen(SH,100) || die "cant listen socket:$!";
	listen(SH,1) || die "cant listen socket:$!";
	while(1){
		sleep 10000;
	}
	close(SH);
}
1;
