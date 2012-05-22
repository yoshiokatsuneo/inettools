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
sub FD_ISSET{
    local($fd,$fdset) = @_;
    return vec($fdset,fileno($fd),1);
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

sub do_accept
{
    local($accept_fh) = @_;
    local($newsession);
    local($client,$server);

    ### make session ###
    local($newsession) = {};
    local($num) = $SESSIONCOUNTER++;
    $$newsession{'NUM'} = $num;
    $SESSION{$num} = $newsession;
    local($client) = "CLIENT$num";
    $$newsession{'CLIENT'} = $client;
    $$newsession{'STATE'} = 'CONNECTING';
    ####################
    print "accept_fh=$accept_fh\n";
    accept($client,$accept_fh) || die "can't accept:$!";

    return $newsession;
}
sub do_connect
{
    local($session,$port,$host) = @_;

    local($server_fh) = "SERVER$$session{NUM}";
    $$session{'SERVER'} = $server_fh;
    socket($server_fh,PF_INET,SOCK_STREAM,0) || die "can't open socket:$!";
    connect($server_fh,sockaddr_in($port,inet_aton($host)))
	|| die "can't connect:$!";
    # NO RETURN
}
sub do_close
{
    local($session) = @_;
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
    delete $SESSION{$$session{'NUM'}};
    # NO RETURN
}
sub change_state
{
    local($session,$state,$crin,$cwin,$srin,$swin) = @_;
    print "#change_state($$session{NUM},$state,$crin,$cwin,$srin,$swin)\n";
    $$session{'STATE'} = $state;
    vec($rin,fileno($$session{'CLIENT'}),1) = $crin;
    vec($win,fileno($$session{'CLIENT'}),1) = $cwin;
    vec($rin,fileno($$session{'SERVER'}),1) = $srin;
    vec($win,fileno($$session{'SERVER'}),1) = $swin;
    # NO RETURN
}



while(1){
    print "# --- select --- \n";
    $ret = select($rout = $rin,$wout=$win,undef,undef);
    print "# select end (ret=$ret)\n";
    while(($num,$session) = each %SESSION){
	# print "num=$num,state=$$session{STATE},client=$$session{CLIENT}\n";
	if($$session{'STATE'} eq 'ACCEPTING'){
	    if(FD_ISSET($$session{'CLIENT'},$rout)){
		$newsession = do_accept($$session{'CLIENT'});
		# print "do_accepted\n";sleep(10);
		do_connect($newsession,$serverport,$serverhost);
		my($cport,$caddr) = unpack_sockaddr_in(getpeername($$newsession{'CLIENT'}));
		print "#($$newsession{NUM})CONNECTING CLIENT(",inet_ntoa($caddr),":",$cport,") => SERVER($serverhost:$serverport)\n";
		### FD_SET ###
		change_state($newsession,'CONNECTING',0,0,0,1);
		# sleep(10);
	    }
	}elsif($$session{'STATE'} eq 'CONNECTING'){
	    if(FD_ISSET($$session{'SERVER'},$wout)){
		print "#($num) CONNECTED\n";

		change_state($session,'READING',1,0,1,0);
	    }
	}elsif($$session{'STATE'} eq 'READING'){
	    if(FD_ISSET($$session{'SERVER'},$rout)){
		local($buf,$n);

		$n = sysread($$session{'SERVER'},$buf,10000);
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel}
		$$session{'BUF'} = $buf;
		print "#($num) SERVER=>CLIENT: $m/$n byte [$buf][",&dump($buf),"]\n";
		change_state($session,'WRITING_CLIENT',0,1,0,0);
	    }elsif(FD_ISSET($$session{'CLIENT'},$rout)){
		local($buf,$n);
		$n = sysread($$session{'CLIENT'},$buf,10000);
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel;}
		$$session{'BUF'} = $buf;
		print "#($num) CLIENT=>SERVER: $m/$n byte [$buf][",&dump($buf),"]\n";
		change_state($session,'WRITING_SERVER',0,0,0,1);
	    }
	}elsif($$session{'STATE'} eq 'WRITING_SERVER'){
	    if(FD_ISSET($$session{'SERVER'},$wout)){
		$n = syswrite($$session{'SERVER'},$$session{'BUF'},length($$session{'BUF'})) || die "#ERROR: WRITING_SERVER:write:$!";
		print "#($num) WRITING($n byte)\n";
		change_state($session,'READING',1,0,1,0);
	    }
	}elsif($$session{'STATE'} eq 'WRITING_CLIENT'){
	    if(FD_ISSET($$session{'CLIENT'},$wout)){
		$n = syswrite($$session{'CLIENT'},$$session{'BUF'},length($$session{'BUF'})) || die "#ERROR: WRITING_CLIENT:write:$!";
		print "#($num) WRITING($n byte)\n";
		change_state($session,'READING',1,0,1,0);
	    }
	}
endlabel:
	if($$session{'STATE'} eq 'CLOSING'){
	    print "#($num) CLOSING...\n";
	    &do_close($session);
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
