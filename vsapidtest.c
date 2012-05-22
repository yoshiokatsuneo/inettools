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
	int s[10000];
	struct sockaddr_un sun;
	char buf[100];
	char sockname[1000]="";
	char *ptr;
	int ret;
	int count =0;
	int i;

	sprintf(sockname,"/var/tmp/fsav");
	if(argc>=2){
		strcpy(sockname, argv[1]);
	}


	memset(&sun, 0, sizeof(sun));
	sun.sun_family = AF_UNIX;
	strcpy(sun.sun_path, sockname);

	while(1){

		for(i=0;i<1000;i++){	
			printf("send count=%d\n", count);
			count ++;
		
			s[i] = socket(AF_UNIX, SOCK_STREAM, 0);
			if(s[i]==-1){perror("socket:");exit(1);}

			ret = connect(s[i], (struct sockaddr*)&sun, sizeof(sun));
			if(ret==-1){perror("connect:");exit(1);}

		//ptr = fgets(buf, sizeof(buf), stdin);
		//if(ptr==NULL){perror("fgets()");exit(1);}
			strcpy(buf,"/usr/src/linux-2.4.21.tar.bz2");
	
			printf("write begin\n");
			ret = write(s[i], buf, strlen(buf)+1);
			printf("write end ret=[%d]\n", ret);
		}

		for(i=0;i<1000;i++){
			printf("receive count=%d\n", count);
			ret = read(s[i], buf, sizeof(buf));
			printf("readed ret=[%d]\n", ret);
			printf("buf=[%s]\n", buf);
			close(s[i]);
		}

	}	
	return 0;
}

