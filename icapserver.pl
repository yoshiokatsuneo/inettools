#!/usr/bin/perl

use Socket;
use POSIX;

sub icap_session
{
	local(*SHA) = @_;
	local($method, $icap_url);
	local($enc_null_body, $enc_req_hdr);

	$_ = <SHA>;
	tr/\r\n//d;
	print "LINE: [$_]\n";
	if(m|^(\S+) (\S+) ICAP/1.0|){
		$method = $1;
		$icap_url = $2;
	}else{
		die "Invalid request line\n";
	}
	while(<SHA>){
		tr/\r\n//d;
		print "LINE: [$_]\n";
		if(/^$/){print "AAA\n";last;}
		if(/^Encapsulated:/){
			if(/(^|[^\w])req-hdr=(\d+)/){$enc_req_hdr = $2;}
			if(/(^|[^\w])null-body=(\d+)/){$enc_null_body = $2;}
		}
	}
	if($enc_null_body){
		$n = read(SHA, $buf_body, $enc_null_body);
		print "BODY: [$buf_body]\n";	
	}
	if($method eq "OPTIONS"){
		print SHA "ICAP/1.0 200 OK\r\n";
		print SHA "Encapsulated: null-body=0\r\n";
		print SHA "Connection: close\r\n";
		print SHA "Methods: REQMOD\r\n";
		print SHA "ISTag: 1111\r\n";
		print SHA "Transfer-Complete: *\r\n";
		print SHA "Allow: 204\r\n";
		print SHA "\r\n";
	}elsif($method eq "REQMOD"){
		$buf_body =~ /^(\S+) (\S+)/;
		$url = $2;
		print "URL: $url\n";
		if($url =~ /block/){
			print "### BLOCK###\n";
if(0){
			local($respbuf) = <<_EOT_;
ICAP/1.0 200 OK
Date: Mon, 10 Jan 2000  09:55:21 GMT
Server: ICAP-Server-Software/1.0
Connection: close
ISTag: "W3E4R7U9-L2E4-2"
Encapsulated: res-hdr=0, res-body=213

HTTP/1.1 403 Forbidden
Date: Wed, 08 Nov 2000 16:02:10 GMT
Server: Apache/1.3.12 (Unix)
Last-Modified: Thu, 02 Nov 2000 13:51:37 GMT
ETag: "63600-1989-3a017169"
Content-Length: 58
Content-Type: text/html

3a
Sorry, you are not allowed to access that naughty content.
0

_EOT_
			$respbuf =~ tr/\r//d;
			$respbuf =~ s/\n/\r\n/g;
			print "RESPBUF: [$respbuf]\n";
			print SHA $respbuf;
}
if(1){
			local($http_body) = "<h1>This is body</h1>\r\n";
			# local($http_resp_header) = "HTTP/1.1 403 OK\r\nContent-Type: text/html\r\nContent-Length: " . length($http_body) . "\r\n\r\n";
			local($http_resp_header) = "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nContent-Length: " . length($http_body) . "\r\n\r\n";
			local($resp_body) = $http_resp_header . sprintf("%x", length($http_body)) . "\r\n" . $http_body . "\r\n0\r\n\r\n";
			print "----------\n";
			print SHA "ICAP/1.0 200 OK\r\n";
			print "ICAP/1.0 200 OK\r\n";
			print SHA "Encapsulated: res-hdr=0, res-body=" . (length($http_resp_header)) . "\r\n";
			print "Encapsulated: res-hdr=0, res-body=" . (length($http_resp_header)) . "\r\n";
			print SHA "ISTag: 2222\r\n";
			print "ISTag: 2222\r\n";
			print SHA "Connection: close\r\n";
			print "Connection: close\r\n";
			print SHA "\r\n";
			print "\r\n";
			print SHA $resp_body;
			print $resp_body;
			print "----------\n";
}
		}else{
			print SHA "ICAP/1.0 204 OK\r\n";
			print SHA "Encapsulated: null-body=0\r\n";
			print SHA "ISTag: 2222\r\n";
			print SHA "\r\n";
		}
	}
}

$port = ($ARGV[0] || 1344);
print "LISTEN PORT: $port ...\n";
socket(SH, PF_INET, SOCK_STREAM, 0) || die "cannot open socket: $!";
setsockopt(SH, SOL_SOCKET, SO_REUSEADDR, 1) || die "setsockopt: $!";
bind(SH, sockaddr_in($port, INADDR_ANY)) || die "cannot bind to me: $!";
listen(SH, SOMAXCONN) || die "cannot listen socket: $!";
while(1){
	local(*SHA);
	accept(SHA, SH) || die "cannot accept socket: $!";
	my($rport,$raddr) = unpack_sockaddr_in(getpeername(SHA));
	print "ACCEPT From: ",inet_ntoa($raddr),":",$rport,"\n";
	select((select(SHA),$|=1)[0]);
	&icap_session(*SHA);
	print "CLOSED\r\n";
	close(SHA);
}

