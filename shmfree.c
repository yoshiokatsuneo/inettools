#include <stdio.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

int main(int argc,char *argv[])
{
  key_t key;
  int shmid;
  int ret;
  int count=0;

  for(key=0;key<1000000;key++){
    shmid = shmget(key,1,0777);
    if(key%1000==0){
      printf("key=%d\n",key);
    }
    if(shmid==-1){continue;}
    ret = shmctl(shmid,IPC_RMID,NULL);
    printf("deleting key=%d ret=%d\n",key,ret);
  }
}
