#!/usr/local/bin/perl
use Socket;
use POSIX;

sub udp_client_setup
{
    local(*SH,$host,$port)=@_;
    # $host is ignoreed
    local($proto,$sin);

    $proto = getprotobyname('udp') || die "getprotobyname:$!";
    socket(SH,PF_INET,SOCK_DGRAM,$proto) || die "socket:$!";
    if($host || $port){
	local($iaddr)=inet_aton($host) || die "Error inet_aton:$!";
	local($sin)=pack_sockaddr_in($port,$iaddr);
	bind(SH,$sin) || die "bind():$!";
    }
}
sub udp_get_sockaddr_in
{
    local($host,$port)=@_;
    local($iaddr,$sin);

    $iaddr = inet_aton($host) || die "inet_aton:$!";
    ($port =~ /\d+/) 
	|| ($port  = getservbyname($port,'udp')) || die "getportbyname:$!";
    $sin   = sockaddr_in($port,$iaddr) || die "sockaddr_in:$!";
    return $sin;
}

if($0 eq __FILE__){
    local($host,$port) = @_;
    
    $host = ($ARGV[0] || 'localhost');
    $port = ($ARGV[1] || 9999);
   
	print "($host,$port)\n";
    &udp_client_setup(*SH);
    $sin=&udp_get_sockaddr_in($host,$port);
    while(<STDIN>){
	chop;
	print "Sending [$_]...\n";
	send(SH,$_,0,$sin) || die "send:$!";
	$ret = recv(SH,$buf,1000000,0);
	#$buf=<SH>;
	print "Recieved [$buf](ret=$ret)\n";
    }
}

1;

