#!/usr/local/bin/perl
use Socket;
use Time::HiRes qw(gettimeofday tv_interval);
use Fcntl;
use POSIX;

$SIG{'PIPE'} = sub{print "SIGPIPE happened\n";};

sub usage
{
    print "usage: tcpmclient.pl -H<server_host> -P<server_port> -C<connection number> -S<allsize>\n";
}
if($0 eq __FILE__){
    $port = 12345;
    $host = "localhost";
    $allsize = 100000;
    $packetsize = 1000;
    $conn = 5;
    while($_=$ARGV[0]){
	if(/^-P/){$port=$';}
	elsif(/^-H/){$host=$';}
	elsif(/^-C/){$conn=$';}
	elsif(/^-S/){$allsize=$';}
	else{print "syntax error\n";}
	shift;
    }
    $ti = &tcpmclient($port,$host,$conn,$allsize);
    print "Time = $ti\n";
}
sub tcpmclient
{
    local($port,$host,$conn,$allsize) = @_;
    local($allsendsize) = 0;
    local(%sendsize);

    $onesize = int($allsize / $conn);
    $SH_BASE = "SH00000";
    $t0 = [gettimeofday];
    for($i=0;$i<$conn;$i++){
	$SH = $SH_BASE++;
	socket($SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	fcntl($SH,F_SETFL,O_NONBLOCK) || die "fcntl:$!";
	inet_aton($host) || die "sockaddr_in:$!";
	$ret = connect($SH,sockaddr_in($port,inet_aton($host)));
	if((! $ret) && $! != EINPROGRESS){
	    die "can't connect:$!";
	}
	# select((select(SH),$|=1)[0]);
	$STATE{$SH} = "WRITE";
	$sendsize{$SH} = 0;
    }
    while(%STATE){
	$win = '';
	while(($SH,$state) = each(%STATE)){
	    vec($win,fileno($SH),1) = 1;
	}
	print "Selecting\n";
	$n = select(undef,$wout=$win,undef,undef);
	print "Selected(n=$n)\n";
	if($n<=0){die "select:$!";}
	%hash = %STATE;
	while(($SH,$state) = each(%hash)){
	    if(vec($wout,fileno($SH),1)==1){
		if($state eq "WRITE"){
		    $buf =  ("0" x ($packetsize-1)) . "\n";
		    $n = send($SH,$buf,0);
		    if($n<=0 && $! != EWOULDBLOCK){
			die "[$SH] send error(n=$n):$!";
		    }
		    if($n>0){
			$sendsize{$SH} += $packetsize;
			$allsendsize += $packetsize;
			$ti = tv_interval($t0);
			print "($ti)[$SH] $sendsize{$SH}/$onesize , $allsendsize/$allsize sended\n";
			if($sendsize{$SH} >= $onesize){
			    close($SH);
			    delete $STATE{$SH};
			    $ti = tv_interval($t0);
			    print "($ti)[$SH] Close\n";
			}
			if($allsendsize>=$allsize){
			    while(($s,undef)=each %STATE){
				close($s);
				delete $STATE{$s};
				$ti = tv_interval($t0);
				print "($ti)[$s] Close\n";
			    }
			    last;
			}
		    }
		}
	    }
	}
    }
    # sleep(10000);
    $ti = tv_interval($t0);
    return $ti;
}

1;
