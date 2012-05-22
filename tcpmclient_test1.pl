#!/usr/local/bin/perl

require 'tcpmclient.pl';

if($0 eq __FILE__){
    $port = 12345;
    $host = "localhost";
    $allsize = 100000;
    $packetsize = 1000;
    $conn = 5;
    $checknum=3;
    while($_=$ARGV[0]){
	if(/^-P/){$port=$';}
	elsif(/^-H/){$host=$';}
	elsif(/^-C/){$conn=$';}
	elsif(/^-S/){$allsize=$';}
	else{print "syntax error\n";}
	shift;
    }
    open(SAVEOUT,">&STDOUT") || die "can't reopen SAVEOUT:$!";
    select(SAVEOUT);$|=1;select(STDOUT);$|=1;
    close(STDOUT);
	for($allsize=20000;$allsize<=100000;$allsize+=20000){
	    for($conn=1;$conn<=8;$conn++){
    for($num=0;$num<$checknum;$num++){
		sleep(1);
		$ti = &tcpmclient($port,$host,$conn,$allsize);
		$line = "$allsize\t$conn\t$ti";
		print SAVEOUT "$line\n";
		push(@results,$line);
	    }
	}
    }
    open(STDOUT,">&SAVEOUT") || die "can't reopen STDOUT:$!";
    foreach $line(@results){
	print $line,"\n";
    }
}

1;
