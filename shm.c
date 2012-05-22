#include <stdio.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

int main(int argc,char *argv[])
{
  int shmid;
  key_t key=100;
  int count=0;
  char *shm;
  int pid;

  while(1){
    int size = 9999;

    if((shmid = shmget(key,size,IPC_CREAT|0777))<0){
      perror("shmget");
      exit(1);
    }

    shm = shmat(shmid,NULL,0);
    strcpy(shm,"11111");
    printf("shm=[%s]\n",shm);
    if((pid=fork())>0){
      strcpy(shm,"22222");
      printf("[parent]shm=[%s]\n",shm);
      sleep(2);
      printf("[parent]shm=[%s]\n",shm);
    }else if(pid==0){
      sleep(1);
      printf("[child]shm=[%s]\n",shm);
      strcpy(shm,"33333");
    }else{
      perror("fork:");
      exit(1);
    }
    exit(1);
#if 0
    strcpy(shm,"11111");
    printf("shm=[%s]\n",shm);
    shmctl(shmid,IPC_RMID,NULL);
    strcpy(shm,"22222");
    printf("shm=[%s]\n",shm);
    shmdt(shm);
    strcpy(shm,"33333");
    printf("shm=[%s]\n",shm);
#endif
    printf("[%d] key=[%d],shmid=[%d]\n",count,key,shmid);
    count++;
    key++;
    exit(1);
  }

  return 0;
}
