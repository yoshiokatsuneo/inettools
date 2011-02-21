#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/un.h>

void do_connect_close(const char *sockname)
{
	int s;
	struct sockaddr_un sun;
	int ret;
	char buf[100];

	s = socket(AF_UNIX, SOCK_STREAM, 0);
	if(s==-1){perror("socket:");exit(1);}

	memset(&sun, 0, sizeof(sun));
	sun.sun_family = AF_UNIX;
	strcpy(sun.sun_path, sockname);

	{
		struct linger linger_opt;

		memset(&linger_opt, 0, sizeof(linger_opt));
		linger_opt.l_onoff = 1;
		linger_opt.l_linger = 0;

		ret = setsockopt(s, SOL_SOCKET, SO_LINGER, &linger_opt, sizeof(linger_opt));
		if(ret<0){perror("linger");exit(1);}
	}

	printf("connecting to [%s]\n", sockname);
	ret = connect(s, (const struct sockaddr*)&sun, sizeof(sun));
	if(ret==-1){perror("connect:");goto endlabel;}
	printf("connected to [%s]\n", sockname);


//	printf("write begin\n");
//	ret = write(s, buf, strlen(buf)+1);
//	printf("write end ret=[%d]\n", ret);

	buf[0]='\0';
	ret = read(s, buf, sizeof(buf));
	printf("readed ret=[%d]\n", ret);
	printf("buf=[%s]\n", buf);

endlabel:
	ret = close(s);
	if(ret<0){perror("close");exit(1);}
}

void handler(int sig)
{
	write(1, "SIGNAL!\n", 8);
}

int main(int argc, char *argv[])
{
	char sockname[1000]="";

	signal(SIGPIPE, handler);

	sprintf(sockname,"/tmp/testsock");
	if(argc>=2){
		strcpy(sockname, argv[1]);
	}

	while(1){
		do_connect_close(sockname);
	}
	
	return 0;
}

