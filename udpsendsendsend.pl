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
    
	$size = ($ARGV[0] || 10000);shift;
    $host = ($ARGV[0] || 'localhost');shift;
    $port = ($ARGV[0] || 9999);shift;
    
    &udp_client_setup(*SH);
    $sin=&udp_get_sockaddr_in($host,$port);
	$buf = "a" x $size;
	while(1){
	send(SH,$buf,0,$sin);
}
}
1;

