#!/usr/bin/perl

use Socket;
use POSIX;

#----------------MAIN-------------------
# if($ARGV[0] eq "-q"){$quiet=1;shift;}
$port = ($ARGV[0] || 12345);
print "LISTEN PORT: $port...\n";
socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
setsockopt(SH,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
bind(SH,sockaddr_in($port,INADDR_ANY)) 	|| die "cant bind to me:$!";
listen(SH,SOMAXCONN) || die "cant listen socket:$!";
while(1){
    accept(SHA,SH) 	|| die "can't accept socket:$!";
    my($rport,$raddr) = unpack_sockaddr_in(getpeername(SHA));
    print "ACCEPT From: ",inet_ntoa($raddr),":",$rport,"\n";
    close(SHA);
}	
close(SH);
