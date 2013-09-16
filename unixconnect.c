#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/un.h>

#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[])
{
	struct sockaddr_un sun;
	int ret;
	char buf[100];
	char sockname[1000]="/tmp/.com.f-secure.fsav/fsavd-socket";

	// sprintf(sockname,"/tmp/.fsav-%d",getuid());
    
	if(argc>=2){
		strcpy(sockname, argv[1]);
	}


    int count = 0;
    while(1){
        int s = socket(AF_UNIX, SOCK_STREAM, 0);
        if(s==-1){perror("socket:");exit(1);}
        
        memset(&sun, 0, sizeof(sun));
        sun.sun_family = AF_UNIX;
        strcpy(sun.sun_path, sockname);

        printf("%d:connecting to [%s]\n", count, sockname);
        ret = connect(s, (struct sockaddr*)&sun, sizeof(sun));
        if(ret==-1){perror("connect:");exit(1);}
        printf("%d:connected to [%s]\n", count, sockname);
        count++;
        usleep(10);
    }
	return 0;
}

