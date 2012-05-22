#!/usr/local/bin/perl

use Socket;

#----------------MAIN-------------------
if($0 eq __FILE__){
	$port = ($ARGV[0] || 12345);
	socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
	setsockopt(SH,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
	bind(SH,sockaddr_in($port,INADDR_ANY)) 	|| die "cant bind to me:$!";
	listen(SH,5) || die "cant listen socket:$!";
	while(1){
		accept(SHA,SH) 	|| die "can't accept socket:$!";
		($port,$addr) = unpack_sockaddr_in(getpeername(SHA));
		print "host=",inet_ntoa($addr),",port=$port\n";
		while(<SHA>){
			print "recieved[$_]\n";
		}
		close(SHA);
	}	
	close(SH);
}
1;
