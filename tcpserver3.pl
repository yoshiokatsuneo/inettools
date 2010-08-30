#!/usr/bin/perl

use Socket;
use POSIX;

sub usage
{
	print "$0 port\n";
}

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
    while(1){
	my($rin);vec($rin,0,1) = 1;vec($rin,fileno(SHA),1)=1;
	$ret = select($rout = $rin,undef,undef,undef);
	if(vec($rout,fileno(STDIN),1)==1){
	    $n = sysread(STDIN,$buf,100000);
	    if($n<=0){print "CLOSE(ACTIVE)\n";last;}
	    $m = syswrite(SHA,$buf,$n);
	    print "SEND: $m/$n byte\n";
	}
	if(vec($rout,fileno(SHA),1)==1){
	    $n = sysread(SHA,$buf,10000000);
	    if($n<=0){print "CLOSE(PASV)\n";last;}
	    ($hex = $buf) =~ s/(.|\n)/unpack("H2",$&) 
		. (isprint($&)?"($&) ":" ")/eg;
	    print "RECIEVE: $n byte[$buf][$hex]\n";
	}
    }
    close(SHA);
}	
close(SH);
