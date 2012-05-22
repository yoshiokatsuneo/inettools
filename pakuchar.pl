#!/usr/local/bin/perl

sub usage
{
    print "Usage: $0 <hostname>\n";
}
if(!@ARGV){
    &usage;
    exit(1);
}
$host = $ARGV[0];

$tmpdir = "/var/tmp/pakuchar.$$";
if(!-d $tmpdir){
    mkdir($tmpdir,0777) || die "mkdir [$mkdir]:$!";
}

$fname_traceroute = "$tmpdir/result.traceroute";
$cmd = "traceroute -w 2 -q 2 $host > $fname_traceroute";
print "Execute [$cmd]...\n";
system($cmd)==0  || die "ERROR: exec[$cmd]:$!";
print "Executed\n";
open(FH,$fname_traceroute) || die "can't open [$fname_traceroute]:$!";
while(<FH>){
    print "line:[$_]\n";;
    if(/^\s*(\d+)\s+(\*\s+)?(\S+)/){
	$host = $3;
	push(@hostlist,$host);
    }
}
close(FH);
unlink $fname_traceroute;

$hostcount=0;
foreach $host(@hostlist){
    $fname_ping = "$tmpdir/result.ping";
    $cmd = "ping -l 1000 $host > $fname_ping";
    print "Executing [$cmd]...\n";
    $pid = fork();
    if($pid==0){
	system($cmd) == 0 || die "can't execute [$cmd]:$!";
	exit 1;
    }
    print "Sleeping 2 second...\n";
    sleep(2);
    print "Killing [$pid]...\n";
    kill 2,$pid;
    sleep(1);
    kill 2,$pid;
    sleep(1);
    kill 9,$pid;
    open(FH,$fname_ping) || die "can't open ping result file [$fname_ping]:$!";
    local($packetnum_trans,$packetnum_recv,$packetloss_percent);
    while(<FH>){
	print "line: [$_]\n";
	#9 packets transmitted, 7 packets received, 22% packet loss
	# if(/^(\d+) packets transmitted, (\d+) packets received, (\d+)\% packet loss/){
	if(/\d+ bytes from /){
	    $packetnum_recv++;
	}
    }
    if($packetnum_recv == 0){
	print "Error: can't found ping response\n";
	# exit 1;
    }
    $packetnum_trans = 1000;
    $packetloss_percent = $packetnum_recv/$packetnum_trans * 100;
    push(@percents,$packetloss_percent);
    close(FH);
    $hostcount++;
}


print "==============================================\n";
$count=0;
foreach $host(@hostlist){
    $percent = $percents[$count];
    $rate = $percent / 2;
    printf("%50s %6.2f [Mbps] // %6.2f [\%]\n"
	   ,$host,$rate,$percent);
    $count++;
}
print "==============================================\n";

