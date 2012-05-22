/* http://ukai.org/b/log/debian/linux/userland_live_patching_consideration */

/* srvtest.c - sample of passing fds 
 *
 * cc -o srvtest servtest.c
 * 
 * server% ./srvtest
 * listening on 33825
 *
 *   basically, it just echo back clients sent.
 *   if '!' line received, connection is passed to standby process.
 *
 * client% telnet localhost 33825
 * Trying 127.0.0.1...
 * Connected to localhost.localdomain.
 * Escape character is '^]'.
 * foo
 * foo
 * bar
 * bar
 * !
 * [ACT pass]
 * [SBY take over]
 * Connection closed by foreign host.
 * 
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>

/* Note: msg_control may be msg_accrights, etc. */

int sendfd(int conn, int fd)
{
    size_t len = sizeof(struct cmsghdr) + sizeof(int);
    struct cmsghdr *hdr = (struct cmsghdr *)malloc(len);
    struct msghdr msg;
    struct iovec iov[1];
    int rc;

    hdr->cmsg_len = len;
    hdr->cmsg_level = SOL_SOCKET;
    hdr->cmsg_type = SCM_RIGHTS;
    *(int *)CMSG_DATA(hdr) = fd;

    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    iov[0].iov_base = "";
    iov[0].iov_len = 1;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    msg.msg_control = hdr;
    msg.msg_controllen = len;

    rc = sendmsg(conn, &msg, 0);
    free(hdr);
    return rc;
}

int recvfd(int conn)
{
    size_t len = sizeof(struct cmsghdr) + sizeof(int);
    struct cmsghdr *hdr = (struct cmsghdr *)malloc(len);
    struct msghdr msg;
    struct iovec iov[1];
    char c;
    int rc;


    iov[0].iov_base = &c;
    iov[0].iov_len = 1;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    msg.msg_control = hdr;
    msg.msg_controllen = len;

    printf("[recvmsg]\n");
    rc = recvmsg(conn, &msg, 0);

    printf("[recvmsg %d len=%d, level=%d, type=%d]\n", 
	   rc, hdr->cmsg_len, hdr->cmsg_level, hdr->cmsg_type);
    if (rc >= 0 
	&& hdr->cmsg_len == len 
	&& hdr->cmsg_level == SOL_SOCKET 
	&& hdr->cmsg_type == SCM_RIGHTS) {
	int fd = *(int *)CMSG_DATA(hdr);
	free(hdr);
	return fd;
    }

    free(hdr);
    return -1;
}

void sigchld(int s)
{
    int st;
    wait(&st);
    return;
}

int main()
{
    int fds[2];
    int fd = -1;
    int sock;
    struct sockaddr_in saddr;
    int salen;
    int rc = socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
    pid_t pid;

    if (rc) {
	perror("socketpair");
	return 1;
    }
    signal(SIGCHLD, sigchld);

    switch (pid = fork()) {
    case 0:
	// standby process
        close(fds[1]);
	while (1) {
	    fd = recvfd(fds[0]);
	    if (fd < 0) {
		perror("recvfd");
		exit(0);
	    }
	    printf("recvfd %d\n", fd);
	    rc = write(fd, "[SBY take over]\n", sizeof("[SBY take over]\n"));
	    if (rc < 0) {
		perror("write");
		exit(0);
	    }
	    close(fd);
	    printf("done\n");
	}
	_exit(0);
    case -1:
	perror("fork");
	return 1;
    default:
	;
    }

    sock = socket(PF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
	perror("socket");
	exit(1);
    }
    salen = sizeof(saddr);
    memset(&saddr, 0, salen);
    rc = bind(sock, &saddr, salen);
    if (rc < 0) {
	perror("bind");
	exit(1);
    }
    rc = getsockname(sock, &saddr, &salen);
    if (rc < 0) {
	perror("getsockname");
	exit(1);
    }
    printf("listening on %d\n", ntohs(saddr.sin_port));
    rc = listen(sock, 5);
    if (rc < 0) {
	perror("listen");
	exit(1);
    }
    while (1) {
	int csock;
	char buf[512];
	int bsiz;
	csock = accept(sock, &saddr, &salen);
	if (csock < 0) {
	    perror("accept");
	    exit(1);
	}
	
	switch (pid = fork()) {
	case 0:
	    /* active process */
	    while ((bsiz = read(csock, buf, sizeof(buf))) > 0) {
		if (bsiz == 0 || buf[0] == '\n' || buf[0] == '\r') {
		    break;
		}
		if (buf[0] == '!') {
		    rc = write(csock, "[ACT pass]\n", sizeof("[ACT pass]\n"));
		    if (rc < 0) {
			perror("write");
			exit(1);
		    }
		    /* hand over to standby process */
		    rc = sendfd(fds[1], csock);
		    if (rc < 0) {
			perror("sendfd");
			exit(1);
		    }
		    printf("[swtich %d]\n", csock);
		    exit(0);
		} else {
		    rc = write(csock, buf, bsiz);
		    if (rc < 0) {
			perror("write");
			exit(1);
		    }
		}
	    }
	case -1:
	    perror("fork");
	    exit(1);
	default:
	    close(csock);
	}
    }
    exit(0);
}

