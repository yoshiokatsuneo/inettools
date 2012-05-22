#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>

void sig_alarm(int sig)
{
	printf("sig_alarm(sig=%d)\n", sig);
	alarm(2);
}


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
	char filename[1000]="/var/tmp/bigfile";

	if(argc>=2){
		strcpy(filename, argv[1]);
	}
	if(argc>=3){
		strcpy(host, argv[2]);
	}
	if(argc>=4){
		port = atoi(argv[3]);
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

	{
		int offset = 0;
		int fsize;
		FILE *fp_r,*fp_w;

		fp_r = fopen(filename, "rb");
		if(!fp_r){
			printf("cannot read open[%s]\n",filename),
			perror("fopen");
			exit(1);
		}
		fp_w = fdopen(dup(s),"wb");
		if(!fp_w){
			printf("cannot write open[%s]\n",filename),
			perror("fopen");
			exit(1);
		}
		{
			int ret;
			struct stat st;

			ret = fstat(fileno(fp_r),&st);
			if(ret == -1){
				perror("fstat:");
				exit(1);
			}
			fsize = st.st_size;
		}
		signal(SIGALRM, sig_alarm);
		alarm(2);
#if 0
		while(fsize>offset){
			int n;
			int writesize = 50000;

			if(fsize - offset <writesize){
				writesize = fsize - offset;
			}
			printf("sendfile begin(s=%d,fileno(fp_r)=%d,offset=%d,writesize=%d)\n", s, fileno(fp_r), offset, writesize);
			n = sendfile(s, fileno(fp_r), &offset, writesize /* fsize - offset */);
			printf("sendfile end n=%d\n", n);
			if(n<=0){
				perror("sendfile:");
				exit(1);	
			}
		}
#else
		{
			int n;
			char buf[50000];

			while((n=fread(buf,1,sizeof(buf),fp_r))>0){
				printf("fread end/fwrite start(n=%d)\n",n);
				n = fwrite(buf,1,n,fp_w);
				printf("fwrite end/fwrite start(n=%d)\n",n);
			}	
			
		}
#endif
		fclose(fp_r);
		fclose(fp_w);
	}
	return 0;
#if 0
	while(fgets(buf, sizeof(buf), stdin)){
		int ret;
		
		printf("write begin\n");
		ret = write(s, buf, strlen(buf)+1);
		printf("write end ret=[%d]\n", ret);
		ret = read(s, buf, sizeof(buf));
		printf("readed ret=[%d]\n", ret);
		printf("buf=[%s]\n", buf);
	}
#endif
	return 0;
}

