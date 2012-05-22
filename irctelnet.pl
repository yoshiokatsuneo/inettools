#!/usr/local/bin/perl

use Socket;
use POSIX;
require 'jcode.pl';

sub dump{
    local($_) = @_;
    s/(.|\n)/unpack("H2",$&) . (isprint($&)?"($&) ":" ")/eg;
    return $_;
}

#----------------MAIN-------------------

# if($ARGV[0] eq "-q"){$quiet=1;shift;}
if($ARGV[0] =~ /^-/){
	print "usage: irctelnet serverport serverhost proxyport\n";
	exit 0;
}
$serverport = ($ARGV[0] || 23);
$serverhost = ($ARGV[1] || 'r2.nifty.ne.jp');
$proxyport = ($ARGV[2] || 8023);

print "#LISTEN PORT: $proxyport...\n";
socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
setsockopt(SH,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
bind(SH,sockaddr_in($proxyport,INADDR_ANY)) 	|| die "cant bind to me:$!";
listen(SH,SOMAXCONN) || die "cant listen socket:$!";

while(1){
    accept(CLIENT,SH) 	|| die "can't accept socket:$!";
    my($rport,$raddr) = unpack_sockaddr_in(getpeername(CLIENT));
    print "#ACCEPT From: ",inet_ntoa($raddr),":",$rport,"\n";
    socket(SERVER,PF_INET,SOCK_STREAM,0) || die "can't open socket:$!";
    connect(SERVER,sockaddr_in($serverport,inet_aton($serverhost))) || die "can't connect:$!";
#    %FORWARD = ('STDIN' => 'SERVER','SERVER' => 'CLIENT','CLIENT'=>'SERVER');
    while(1){
	
	my($rin);

	#foreach $fh(keys %FORWARD){
	#    vec($rin,fileno($fh),1) = 1;
	#}
	vec($rin,fileno(STDIN),1) = 1;
	vec($rin,fileno(SERVER),1) = 1;
	vec($rin,fileno(CLIENT),1) = 1;
	$ret = select($rout = $rin,undef,undef,undef);

	#while(($fh_from,$fh_to) = each(%FORWARD)){
	#    if(vec($rout,fileno($fh_from),1)){
	#	$n = sysread($fh_from,$buf,100000);
	#	if($n<=0){print "CLOSE by $fh_from\n";last;}
	#	$m = syswrite($fh_to,$buf,$n);
	#	if($m<=0){print "$fh_from->$fh_to: Write Error\n";last;}
	#	print "$fh_from=>$fh_to: $m/$n byte [$buf][",&dump($buf),"]\n";
	#    }
	#}
	if(vec($rout,fileno(STDIN),1)==1){
	    $n = sysread(STDIN,$buf,10000000);
	    if($n<=0){print "#CLOSE by STDIN\n";last;}
	    $m = syswrite(SERVER,$buf,$n);
	    if($m<=0){print "#STDIN->SERVER: Write Error\n";last;}
	    print "STDIN=>SERVER: $m/$n byte [$buf][",&dump($buf),"]\n";
	}
	if(vec($rout,fileno(CLIENT),1)==1){
	    $n = sysread(CLIENT,$buf,10000000);
	    if($n<=0){print "#CLOSE by CLIENT\n";last;}
            $buf =~ s|^PRIVMSG \S+ :||;
	    $m = syswrite(SERVER,$buf,$n);
	    if($m<=0){print "#CLIENT->SERVER: Write Error\n";last;}
	    print "CLIENT=>SERVER: $m/$n byte [$buf][",&dump($buf),"]\n";
	}
	if(vec($rout,fileno(SERVER),1)==1){
	    $n = sysread(SERVER,$buf,10000000);
	    if($n<=0){print "#CLOSE(SERVER)\n";last;}
	    if($buf !~ /\n$/){$buf .= "\n";}
		&jcode'convert(*buf,'jis','euc');
# irc.kyoto.wide.ad.jp 421 tsuneo2 aa :Unknown command
  	 	$buf =~ s/^/$serverhost 001 user aa :/;
	    $m = syswrite(CLIENT,$buf,$n);
	    if($m<=0){print "#SERVER->CLIENT: Write Error\n";last;}
	    print "SERVER=>CLIENT: $m/$n byte [$buf][",&dump($buf),"]\n";
	}
    }
    close(SERVER);
    close(CLIENT);
}
close(SH);
