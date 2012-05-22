#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char*argv[])
{

	int pid;
	int ret;
	int p2c[2];
	int c2p[2];

	if(pipe(p2c)==-1){perror("pipe()");exit(1);}
	if(pipe(c2p)==-1){perror("pipe()");exit(1);}
	pid = fork();
	if(pid<0){
		perror("fork()");
		exit(1);
	}else if(pid>0){ //child
		int count=0;
		while(1){
			char buf[100]="";
			int ret;

			if((count%10000)==0)printf("child: count=%d\n", count);
			count++;
			//printf("child: read begin\n");
			ret = read(p2c[0],buf,sizeof(buf));
			//printf("child: read end buf=[%s],ret=[%d]\n", buf, ret);

			strcpy(buf,"PONG");
			//printf("child: write begin buf=[%s]\n", buf);
			ret = write(c2p[1],buf,strlen(buf)+1);
			//printf("child: write end ret=[%d]\n", ret);
		}
	}else{ // parent
		int count=0;
		while(1){
			char buf[100]="";
			int ret;

			if((count%10000)==0)printf("parent: count=%d\n", count);
			count++;
			strcpy(buf,"PING");
			//printf("parent: write begin [%s]\n", buf);
			ret = write(p2c[1],buf,strlen(buf)+1);
			//printf("parent: write end ret=[%d]\n", ret);

			//printf("parent: read begin\n");
			ret = read(c2p[0],buf,sizeof(buf));
			//printf("parent: read end buf=[%s],ret=[%d]\n", buf, ret);
		}
	}
	return 0;

}

