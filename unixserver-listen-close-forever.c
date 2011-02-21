#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/un.h>
#include <poll.h>

int do_listen_close(const char *sockname)
{
	int ret;
	int s;
	struct sockaddr_un saun, fsaun;

	s = socket(AF_UNIX, SOCK_STREAM, 0);
	if(s<0){perror("socket error");}

	memset(&saun, 0, sizeof(saun));
	saun.sun_family = AF_UNIX;
	strcpy(saun.sun_path, sockname);

        {
                struct linger linger_opt;

                memset(&linger_opt, 0, sizeof(linger_opt));
                linger_opt.l_onoff = 1;
                linger_opt.l_linger = 0;

                ret = setsockopt(s, SOL_SOCKET, SO_LINGER, &linger_opt, sizeof(linger_opt));
                if(ret<0){perror("linger");exit(1);}
        }



	printf("binding [%s]\n", sockname);
	ret = bind(s, (struct sockaddr*)&saun, sizeof(saun));
	if(ret<0){perror("bind:"); exit(1);}

	printf("listening [%s]\n", sockname);
	ret = listen(s, 0);
	if(ret<0){perror("listen"); exit(1);}

	// sleep(1);

#if 0
	printf("shutdowning [%s]\n", sockname);
	ret = shutdown(s, SHUT_RDWR);
	if(ret<0){perror("shutdown"); /* exit(1); */}
#endif

#if 0
	printf("unlinking [%s]\n", sockname);
	ret = unlink(sockname);
	if(ret<0){perror("unlink"); exit(1);}
#endif

	printf("renaming [%s]\n", sockname);
	ret = rename(sockname, "/tmp/testsock-ren");
	if(ret<0){perror("rename"); exit(1);}

	while(1){
		int as;
		struct pollfd pfd;

		pfd.fd = s;
		pfd.events = POLLIN;
		ret = poll(&pfd, 1, 0);
		if(ret == -1){perror("poll"); exit(1);}

		if(ret == 0){
			printf("poll returned 0\n");
			break;
		}
		//printf("sleeping\n");
		//sleep(10);
		printf("accepting...\n");
		as = accept(s, NULL, NULL);
		if(as<0){perror("accept fail\n"); exit(1);}
		printf("acceptted...\n");

		//printf("shutdown...\n");
		//ret = shutdown(as, SHUT_RDWR);
		//if(ret<0){perror("shutdown\n"); exit(1);}

        {
                struct linger linger_opt;

                memset(&linger_opt, 0, sizeof(linger_opt));
                linger_opt.l_onoff = 1;
                linger_opt.l_linger = 0;

                ret = setsockopt(as, SOL_SOCKET, SO_LINGER, &linger_opt, sizeof(linger_opt));
                if(ret<0){perror("linger");exit(1);}
        }

		close(as);
		//printf("sleeping 3 sec after close\n");
		//sleep(3);
	
	}	

	printf("closing [%s]\n", sockname);
	ret = close(s);
	if(ret<0){perror("close"); exit(1);}

}

int main(int argc, char*argv[])
{
	int i = 0;

	char sockname[1000]="/tmp/testsock";

	if(argc>=2){
		strcpy(sockname, argv[1]);
	}

	printf("sockname=[%s]\n", sockname);

	while(1){
		// snprintf(sockname, sizeof(sockname), "/tmp/testsock-%d", i);
		do_listen_close(sockname);
		i++;
	}

	return 0;
}


