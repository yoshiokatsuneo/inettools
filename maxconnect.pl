#!/usr/local/bin/perl

use Socket;

$count = 1;
$port = $ARGV[0] || 8000;
$host = $ARGV[1] || "wwwproxy";
$sin = sockaddr_in($port,inet_aton($host));
while(1){
	if(! socket($count,PF_INET,SOCK_STREAM,0)){
		die "can't open [${count}] socket: $!";
	}
	print "[$count] socket opened.\n";
	
	if(! connect($count,$sin)){
#	if(! connect($count,sockaddr_in($port,inet_aton($host)))){
		die "can't connect [$host:$port]:$!";
	}
	print "[$count] socket connected.\n";
	$count++;
}

