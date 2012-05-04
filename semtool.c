#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <errno.h>
#include <string.h>

//__asm__(".symver __old_semctl,semctl@GLIBC_2.0");
//#define semctl __old_semctl

// #include "old_sem.h"

#ifdef __linux__
       union semun {
            int val;                    /* value for SETVAL */
            struct semid_ds *buf;       /* buffer for IPC_STAT, IPC_SET */
            unsigned short int *array;  /* array for GETALL, SETALL */
            struct seminfo *__buf;      /* buffer for IPC_INFO */
       };
#endif


void usage()
{
	puts("semtool [command] [arguments]");
	puts("  command:");
	puts("    semget <key>");
	puts("    rmid <id>");
	puts("    rmkey <key>");
	puts("    rmkeys <key1> <key2>");
	puts("    getval <id>");
	puts("    setval <id> <val>");
	puts("  option:");
	puts("    --loop <num>: loop <num> times (for debug)");
}
int main(int argc, char *argv[])
{
	int ret;
	int semid;
	int key, key2;
	char cmd[1000]="";
	int loopnum = 1;
	int arg_val;
	int arg_semop;
	int i;

	while(argv++, --argc){
		if(strcmp(*argv, "rmid")==0 && argc==2){
			strcpy(cmd, *argv); argv++, --argc;
			semid = atoi(*argv);
			break;
		}else if(strcmp(*argv, "rmkey")==0 && argc==2){
			strcpy(cmd, *argv); argv++, --argc;
			key = atoi(*argv);
			break;
		}else if(strcmp(*argv, "rmkeys")==0 && argc==3){
			strcpy(cmd, *argv); argv++, --argc;
			key = atoi(*argv);
			argv++, --argc;
			key2 = atoi(*argv);
			break;
		}else if(strcmp(*argv, "semget")==0 && argc==2){
			strcpy(cmd, *argv); argv++, --argc;
			if(strcmp(*argv, "private")==0){
				key = IPC_PRIVATE;
			}else{
				key = atoi(*argv);
			}
			break;
		}else if(strcmp(*argv, "getval")==0 && argc==2){
			strcpy(cmd, *argv); argv++, --argc;
			semid = atoi(*argv);
			break;
		}else if(strcmp(*argv, "setval")==0 && argc==3){
			strcpy(cmd, *argv); argv++, --argc;
			semid = atoi(*argv);
			argv++, --argc;
			arg_val = atoi(*argv);
			break;
		}else if(strcmp(*argv, "semop")==0 && argc==3){
			strcpy(cmd, *argv); argv++, --argc;
			semid = atoi(*argv);
			argv++, --argc;
			arg_semop = atoi(*argv);
			break;
		}else if(strcmp(*argv, "loop")==0 && argc>=2){
			argv++, --argc;
			loopnum = atoi(*argv);
		}else{
			strcpy(cmd, *argv);
			usage();
			exit(0);
		}
	}
	if(strcmp(cmd,"")==0){
		usage();
		exit(0);
	}

	for(i=0; i<loopnum; i++){
		if(strcmp(cmd,"rmid")==0){
			ret = semctl(semid, 0, IPC_RMID);
			if(ret==-1){perror("semget:");exit(1);}
		}else if(strcmp(cmd,"rmkey")==0){
			semid = semget(key, 1, 0666|IPC_CREAT);
			if(semid==-1){perror("semget:");exit(1);}
			ret = semctl(semid, 0, IPC_RMID);
			if(ret==-1){perror("semget:");exit(1);}
		}else if(strcmp(cmd,"rmkeys")==0){
			int j;
			for(j=key; j<key2; j++){
				semid = semget(j, 1, 0666);
				if(semid==-1){
					printf("semget(key=%d): error=[%s]\n", j, strerror(errno));
				}
				ret = semctl(semid, 0, IPC_RMID);
				if(ret==-1){
					printf("semctl-RMID(key=%d, semid=%d): error=[%s]\n", key, semid, strerror(errno));
				}
			}
		}else if(strcmp(cmd,"semget")==0){
			semid = semget(key, 1, 0666|IPC_CREAT);
			if(semid==-1){perror("semget:");exit(1);}
			printf("semid=[%d]\n", semid);
		}else if(strcmp(cmd,"getval")==0){
			union semun c_arg;
			ret = semctl(semid, 0, GETVAL, c_arg);
			if(ret==-1){perror("semctl:");exit(1);}
			printf("ret=%d\n", ret);
		}else if(strcmp(cmd,"setval")==0){
			union semun c_arg;
			c_arg.val = arg_val;
			ret = semctl(semid, 0, SETVAL, c_arg);
			if(ret==-1){perror("semctl:");exit(1);}
		}else if(strcmp(cmd,"semop")==0){
			struct sembuf sb;
			sb.sem_num = 0; sb.sem_op = arg_semop; sb.sem_flg = 0;
			ret = semop(semid, &sb, 1);
			if(ret==-1){perror("semop:");exit(1);}
		}else{
			puts("ERROR"); exit(1);
		}
	}
	return 0;
}



