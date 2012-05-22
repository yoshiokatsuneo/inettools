#!/usr/local/bin/perl

use Socket;

$count = 1;
while(1){
	if(! socket($count,PF_INET,SOCK_STREAM,0)){
		die "can't open [${count}] socket: $!";
	}
	print "[$count] socket opened.\n";
	$count++;
}

