#include <pthread.h>
#include "sockutil.h"
#include "sock.h"
#include <stdio.h>

#define MAX_THREAD 100

pthread_mutex_t thread_num_mutex = PTHREAD_MUTEX_INITIALIZER;
int thread_num=0;

int thread_counter = 0;

void *thread_func(void *arg)
{
  int sconn = (int )arg;
  SOCK *sp = NULL;
  int err = -1;
  int sconn_old = sconn;
  int thread_num_tmp;

  printf("[%d][%d] START\n",sconn,thread_num);
  pthread_mutex_lock(&thread_num_mutex);
  thread_counter++;
  thread_num++;
  pthread_mutex_unlock(&thread_num_mutex);

  
  (sp = sockfdopen(sconn)) || die("[%d]sockfdopen:",sconn);

  /* HTTP Session */
  {
    char buf[4096];
    int ver10,ver1;
    char path[1000];

    if(sockgets(buf,sizeof(buf),sp)==NULL){
      perror("sockgets():");
      goto endlabel;
    }
    if(sscanf(buf,"GET %s HTTP/%d.%d",path,&ver10,&ver1)!=3){
      puts("scanf error\n");
      goto endlabel;}
    while(sockgets(buf,sizeof(buf),sp)){
      if(*buf =='\0' || *buf=='\r' || *buf=='\n'){break;}
      /* printf("HEADER[%s]\n",buf); */
    }
    strcpy(buf,"=====BODY=====\n");
/*  if(fp_r){fclose(fp_r);fp_r=NULL;} */

    sockprintf(sp,"HTTP/1.0 200 OK\r\n");
    sockprintf(sp,"Content-Length: %d\r\n",strlen(buf));
    sockprintf(sp,"\r\n");
    sockputs(buf,sp);
    sockflush(sp);
  }
  /* printf("[%d]: Sleeping...\n",sconn); */
  sleep(10);
  err = 0;
 endlabel:

  if(sp){sockclose(sp);sp=NULL;sconn=0;}
  if(sconn){close(sconn);sconn=0;}

  pthread_mutex_lock(&thread_num_mutex);
  thread_num--;
  thread_num_tmp = thread_num;
  pthread_mutex_unlock(&thread_num_mutex);
  printf("[%d][%d] END(%d)\n",sconn_old,thread_num_tmp,err);
}
int main(int argc,char *argv[])
{
  int port = 12345;
  int s;
  struct sockaddr_in addr;

  argv++,argc--;
  if(argc){ port = atoi(*argv++);argc--;}
  (s = socket0(PF_INET,SOCK_STREAM,0)) || die("socket:");
  setsockopt0_int(s,SOL_SOCKET,SO_REUSEADDR,1) || die("setsockopt:");
  bind0(s, sockaddr_in(port,INADDR_ANY)) || die ("bind:");
  listen0(s,SOMAXCONN) || die("listen:");

  /* pthread_mutex_init(&thread_num_mutex,NULL); */
  while(1){
    int sconn;
    pthread_t thread;
    int ret;

    (sconn = accept0(s)) || die ("accept:");
    getpeername0(sconn,&addr) || die("getpeername:");
    /* printf("port=%d,addr=%08x\n",ntohl(addr.sin_port),ntohl(addr.sin_addr.s_addr)); */
    if(thread_num > MAX_THREAD){
      printf("#########Too match thread. closing connection.(thread_num=%d)\n");
      close(sconn);
      continue;
    }
    printf("[%d][%d] PRE_THREAD_CREATE\n",sconn,thread_num);
    ret = pthread_create(&thread,NULL,thread_func,(void*)sconn);
    printf("[%d][%d] POST_THREAD_CREATE\n",sconn,thread_num);
    pthread_detach(thread);
    /* printf("sconn=%d,thread=%d,ret=%d,thread_counter=%d\n",sconn,thread,ret,thread_counter); */
   }
}
