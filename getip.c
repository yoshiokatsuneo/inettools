#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/ioctl.h>
#include <net/if.h> 


struct in_addr getifaddr(char *ifname)
{
	int s;
	struct ifreq ifr;
	int ret;
	struct sockaddr_in *psin;

	s = socket(AF_INET, SOCK_DGRAM, 0);
	if(s==-1){perror("socket");exit(1);}

	memset(&ifr, 0, sizeof(ifr));	
	strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name)-1);

	ret = ioctl(s, SIOCGIFADDR, (caddr_t)&ifr);
	if(ret == -1){perror("ioctl(SIOCIFADDR)");exit(1);}

	psin = (struct sockaddr_in *)&ifr.ifr_addr;
	// printf("addr=%s:%d\n", inet_ntoa(psin->sin_addr), ntohs(psin->sin_port));
	close(s);
	return psin->sin_addr;
}
int main(int argc, char *argv[])
{
	struct in_addr addr;
	char ifname[100]="eth0";

	if(argc>=2){strcpy(ifname,argv[1]);}
	addr = getifaddr(ifname);
	printf("addr=%s\n", inet_ntoa(addr));
}

