#!/usr/local/bin/perl

use Socket;

$host = ($ARGV[0] || 'localhost');
$port = ($ARGV[1] || 9999);
print "port = $port\n";
if(!($port =~/^\d/)){$port = (getservbyname($port,'udp'))[2];}

socket(SH,AF_INET,SOCK_DGRAM,0) || die "Error: socket:$!";
$iaddr = inet_aton($host) || die "Error: inet_aton:$!";
$sin = sockaddr_in($port,$iaddr) || die "Error: sockaddr_in:$!";

(($p,$a) = unpack_sockaddr_in($sin)) || die "Error:$!";
print "($p,",inet_ntoa($a),")\n";

$rin = '';
vec($rin,fileno(SH),1) = 1;
vec($rin,fileno(STDIN),1) = 1;

while(1){
    $n = select($rout=$rin,undef,undef,undef);
    if($n<=0){
	print "Error: select(n=$n);$!";
	last;
    }
    if(vec($rout,fileno(SH),1)==1){
	$fromsin = recv(SH,$buf,1000,0);
	($p,$a) = unpack_sockaddr_in($fromsin);
	$hex = $buf;
	$hex =~ s/(.|\n)/unpack("H2",$&) . ((($& ge ' ') && ($& le '~'))?"($&) ":" ")/eg;
	print "Receive: from($p,",inet_ntoa($a),"):[$buf][$hex]\n";
	if($fromsin eq ''){last;}
	# $n = syswrite(STDOUT,$buf,length($buf));
    }
    if(vec($rout,fileno(STDIN),1)==1){
	$n = sysread(STDIN,$buf,1000);
	if($n==0){last;}
	$buf =~ s/\n$//;
	print "Send: [$buf]\n";
	$n = send(SH,$buf,0,$sin);
    }
}
close(SH);
