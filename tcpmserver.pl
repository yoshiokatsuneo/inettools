#!/usr/local/bin/perl

use Socket;
use Time::HiRes qw(gettimeofday tv_interval);

$p = 1;
#----------------MAIN-------------------
if($0 eq __FILE__){
	$port = ($ARGV[0] || 12345);
	socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
	setsockopt(SH,SOL_SOCKET,SO_REUSEADDR,1) || die "can't setsockopt(SO_REUSEADDR):$!";
	bind(SH,sockaddr_in($port,INADDR_ANY)) 	|| die "cant bind to me:$!";
	listen(SH,5) || die "cant listen socket:$!";

	$| = 1;
	$allrecieved = 0;
	$SHABASE = "SHA00000";
	$SHA = $SHABASE ++;
	open($SHA,"<&SH") || die "can't reopen:";  
	$SHAHASH{$SHA} = "ACCEPT";
	while(1){
	    $rin ='';
	    while(($SHA,undef) = each %SHAHASH){
		# print "Setting $SHA(fileno=",fileno($SHA),")\n";
		vec($rin,fileno($SHA),1) = 1;
	    }
	    print "Selecting\n" if($p);
	    $n = select($rout=$rin,undef,undef,undef);
	    $n>0 || die "select:";
	    print "Selected(n=$n)\n" if($p) ;
	    %hash=%SHAHASH;
	    while(($SHA,$state) = each %hash){
#		print "SHA=$SHA,state=$state\n";
		if(vec($rout,fileno($SHA),1)==1){
#		    print "SELECT hit [$SHA]\n";
		    if($state eq "ACCEPT"){
			$NEW_SHA = $SHABASE ++;
		      #	print "Accepting1\n";
			accept($NEW_SHA,$SHA) || die "accept:";
		      #	print "Accepted\n";
			if(scalar(keys %SHAHASH)==1){
		      	print "Accepting\n";
			    $t0 = [gettimeofday()];
			    $allrecieved=0;
			    $conn = 0;
			}
			$conn++;
			$SHAHASH{$NEW_SHA} = "READ";
			print "(",tv_interval($t0),")[$NEW_SHA] Accepted\n" if($p);
		    }elsif($state eq "READ"){
			$n = sysread($SHA,$buf,1000000);
			if($n>0){$allrecieved+=$n;}
			print "(",tv_interval($t0),")[$SHA] $n($allrecieved) byte recieved\n" if($p);
			#print "MSG = [$buf]\n";
			if($n<=0){
			    close($SHA);
			    delete $SHAHASH{$SHA};
			    print "[$SHA] closed\n" if($p);
			    if(scalar(keys %SHAHASH)==1){
				$ti = tv_interval($t0);
				print "$allrecieved\t$conn\t$ti\n";
			    }
			}
		    }
		}
	    }
	}
	close(SH);
}
1;
