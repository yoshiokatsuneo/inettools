#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/un.h>

int main(int argc, char *argv[])
{
	int s;
	struct sockaddr_un sun;
	int ret;
	char buf[100];
	char sockname[1000]="";

	sprintf(sockname,"/tmp/.fsav-%d",getuid());
	if(argc>=2){
		strcpy(sockname, argv[1]);
	}

	s = socket(AF_UNIX, SOCK_STREAM, 0);
	if(s==-1){perror("socket:");exit(1);}

	memset(&sun, 0, sizeof(sun));
	sun.sun_family = AF_UNIX;
	strcpy(sun.sun_path, sockname);

	printf("connecting to [%s]\n", sockname);
	ret = connect(s, &sun, sizeof(sun));
	if(ret==-1){perror("connect:");exit(1);}
	printf("connected to [%s]\n", sockname);

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

