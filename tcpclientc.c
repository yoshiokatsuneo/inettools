#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

int main(int argc, char *argv[])
{
	int s;
	struct sockaddr_in sin;
	struct hostent *phent;
	struct in_addr addr;
	int ret;
	char buf[100];
	int port = 12345;
	char addrstr[100];
	char host[1000] = "localhost";
	in_addr_t addrt;

	if(argc>=2){
		strcpy(host, argv[1]);
	}
	if(argc>=3){
		port = atoi(argv[2]);
	}

	phent = gethostbyname(host);
	if(!phent){
		perror("gethostbyname:");
		strcpy(addrstr, host);
	}else{
		memcpy(&addr, phent->h_addr, phent->h_length);
		strcpy(addrstr, inet_ntoa(addr));
	}

	s = socket(PF_INET, SOCK_STREAM, 0);
	if(s==-1){perror("socket:");exit(1);}

	memset(&sin, 0, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_port = ntohs(port);
	addrt = inet_addr(addrstr);
	memcpy(&sin.sin_addr,&addrt,4);
	ret = connect(s, &sin, sizeof(sin));
	if(ret==-1){perror("connect:");exit(1);}

	{
		struct linger l;
		int ret;

		l.l_onoff = 0;
		l.l_linger = 0;
		ret = setsockopt(s,SOL_SOCKET,SO_LINGER,&l,sizeof(l));
		if(ret==-1){perror("setsockoet(SO_LINGER):");exit(1);}
	}

	while(fgets(buf, sizeof(buf), stdin)){
		int ret;
		
		printf("write begin\n");
		ret = write(s, buf, strlen(buf)+1);
		printf("write end ret=[%d]\n", ret);
		ret = read(s, buf, sizeof(buf));
		printf("readed ret=[%d]\n", ret);
		printf("buf=[%s]\n", buf);
	}	
	return 0;
}

