#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/un.h>

int main(int argc, char*argv[])
{
	int s, ns;
	struct sockaddr_un saun, fsaun;
	char sockname[1000]="/tmp/testsock";
	int ret;
	int fromlen;
	FILE *fp;
	char buf[1024];

	if(argc>=2){
		strcpy(sockname, argv[0]);
	}

	printf("sockname=[%s]\n", sockname);

	s = socket(AF_UNIX, SOCK_STREAM, 0);
	if(s<0){perror("socket error");}

	memset(&saun, 0, sizeof(saun));
	saun.sun_family = AF_UNIX;
	strcpy(saun.sun_path, sockname);

	ret = bind(s, (struct sockaddr*)&saun, sizeof(saun));
	if(ret<0){perror("bind:"); exit(1);}

	ret = listen(s, 0);
	if(ret<0){perror("listen"); exit(1);}

	sleep(1000);

	return 0;
}


