#!/usr/bin/perl
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
    
    &udp_client_setup(*SH);
    $sin=&udp_get_sockaddr_in($host,$port);
    while(<STDIN>){
	print "Sending [$_]...\n";
	send(SH,$_,0,$sin) || die "send:$!";
	$buf=<SH>;
	print "Recieved [$buf]\n";
    }
}

1;

