#!/usr/local/bin/perl

use Socket;
use POSIX;

sub dump{
    local($_) = @_;
    s/(.|\n)/unpack("H2",$&) . (isprint($&)?"($&) ":" ")/eg;
    return $_;
}
sub FD_SET{
    local($fd,$fdset) = @_;
    vec($$fdset,fileno($fd),1) = 1;
}
sub FD_CLR{
    local($fd,$fdset) = @_;
    vec($$fdset,fileno($fd),1) = 0;
}

#----------------MAIN-------------------

# if($ARGV[0] eq "-q"){$quiet=1;shift;}
$serverport = ($ARGV[0] || 12345);
$serverhost = ($ARGV[1] || 'localhost');
$proxyport = ($ARGV[2] || 9999);

print "#LISTEN PORT: $proxyport...\n";
socket(ACCEPT,PF_INET,SOCK_STREAM,0) || die "cant open socket:$!";
setsockopt(ACCEPT,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
bind(ACCEPT,sockaddr_in($proxyport,INADDR_ANY)) || die "cant bind to me:$!";
listen(ACCEPT,SOMAXCONN) || die "cant listen socket:$!";


# 'ACCEPTING'   (select(CLIENT,READ))
#     => accept => connect to server =>
# 'CONNECTING'  (select(SERVER,WRITE))
#     =>
# 'READING'     (select((STDIN|CLIENT|SERVER),READ));
#     =>read
# 'WRITING'     (select((SERVER|SERVER|CLIENT),WRITE));
#     =>write
#  ....CLOSE

$SESSIONCOUNTER = 0;

### make session ###
local($session) = {};
$num = $SESSIONCOUNTER++;
$$session{"CLIENT"} = "ACCEPT";
$$session{"SERVER"} = '';
$$session{"STATE"} = "ACCEPTING";
FD_SET($$session{'CLIENT'},\$rin);
# vec($rin,fileno($$session{"CLIENT"}),1) = 1;
$SESSION{$num} =  $session ;
$session = $SESSION{$num};

while(1){
    print "# SELECTING\n";
    $ret = select($rout = $rin,$wout=$win,undef,undef);
    print "# SELECTED(ret=$ret)\n";
    while(($num,$session) = each %SESSION){
	# print "num=$num,state=$$session{STATE},client=$$session{CLIENT}\n";
	if($$session{'STATE'} eq 'ACCEPTING'){
	    if(vec($rout,fileno($$session{'CLIENT'}),1)){
		### make session ###
		local($newsession) = {};
		$num = $SESSIONCOUNTER++;
		$client = "CLIENT$num";
		$server = "SERVER$num";
		$$newsession{"CLIENT"} = $client;
		$$newsession{"SERVER"} = $server;
		$$newsession{'STATE'} = "CONNECTING";
		$$newsession{'NUM'} = $num;
		$SESSION{$num} = $newsession;
		####################

		accept($client,$$session{'CLIENT'}) || die "can't accept:$!";
		socket($server,PF_INET,SOCK_STREAM,0) || die "can't open socket:$!";
		connect($server,sockaddr_in($serverport,inet_aton($serverhost))) || die "can't connect:$!";
		my($rport,$raddr) = unpack_sockaddr_in(getpeername($client));
		print "#($num)CONNECTING CLIENT(",inet_ntoa($raddr),":",$rport,") => SERVER($serverhost:$serverport)\n";
		### FD_SET ###
		FD_SET($server,\$win);
	    }
	}elsif($$session{'STATE'} eq 'CONNECTING'){
	    if(vec($wout,fileno($$session{'SERVER'}),1)){
		$$session{'STATE'} = 'READING';
		FD_CLR($$session{'SERVER'},\$win);

		FD_SET($$session{'SERVER'},\$rin);
		FD_SET($$session{'CLIENT'},\$rin);
		print "#($num) CONNECTED\n";
	    }
	}elsif($$session{'STATE'} eq 'READING'){
	    if(vec($rout,fileno($$session{'SERVER'}),1)){
		$n = sysread($$session{'SERVER'},$buf,10000);
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel}
		$$session{'BUF'} = $buf;
		FD_CLR($$session{'SERVER'},\$rin);
		FD_CLR($$session{'CLIENT'},\$rin);

		FD_SET($$session{'CLIENT'},\$win);
		$$session{'STATE'} = 'WRITING_CLIENT';
		print "#($num) SERVER=>CLIENT: $m/$n byte [$buf][",&dump($buf),"]\n";
	    }elsif(vec($rout,fileno($$session{'CLIENT'}),1)){
		$n = sysread($$session{'CLIENT'},$buf,10000);
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel;}
		$$session{'BUF'} = $buf;
		FD_CLR($$session{'SERVER'},\$rin);
		FD_CLR($$session{'CLIENT'},\$rin);

		FD_SET($$session{'SERVER'},\$win);
		$$session{'STATE'} = 'WRITING_SERVER';
		print "#($num) CLIENT=>SERVER: $m/$n byte [$buf][",&dump($buf),"]\n";
	    }
	}elsif($$session{'STATE'} eq 'WRITING_SERVER'){
	    if(vec($wout,fileno($$session{'SERVER'}),1)){
		$n = syswrite($$session{'SERVER'},$$session{'BUF'},length($$session{'BUF'})) || die "#ERROR: WRITING_SERVER:write:$!";
		print "#($num) WRITING($n byte)\n";

		FD_CLR($$session{'SERVER'},\$win);

		FD_SET($$session{'SERVER'},\$rin);
		FD_SET($$session{'CLIENT'},\$rin);
		$$session{'STATE'} = 'READING';
	    }
	}elsif($$session{'STATE'} eq 'WRITING_CLIENT'){
	    if(vec($wout,fileno($$session{'CLIENT'}),1)){
		$n = syswrite($$session{'CLIENT'},$$session{'BUF'},length($$session{'BUF'})) || die "#ERROR: WRITING_CLIENT:write:$!";
		print "#($num) WRITING($n byte)\n";

		FD_CLR($$session{'CLIENT'},\$win);

		FD_SET($$session{'SERVER'},\$rin);
		FD_SET($$session{'CLIENT'},\$rin);
		$$session{'STATE'} = 'READING';
	    }
	}
endlabel:
	if($$session{'STATE'} eq 'CLOSING'){
	    print "#($num) CLOSING...\n";
	    if($$session{'CLIENT'}){
		FD_CLR($$session{'CLIENT'},\$win);
		FD_CLR($$session{'CLIENT'},\$rin);
		close($$session{'CLIENT'});
	    }
	    if($$session{'SERVER'}){
		FD_CLR($$session{'SERVER'},\$win);
		FD_CLR($$session{'SERVER'},\$rin);
		close($$session{'SERVER'});
	    }
	    delete $SESSION{$$session{'NUM'}}
	}
    }
}
close(SH);
