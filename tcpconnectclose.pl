#!/usr/bin/perl
use Socket;

$port = $ARGV[0] || 12345;
$host = $ARGV[1] || localhost;
local($i)=0;
while(1){
	local($SH) = "SH-$i";
	socket($SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	print "connecting... (count=$i)\n";
	$i++;
	setsockopt($SH,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
	connect($SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
	sleep(0);
	close($SH);
}

