#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>

__asm__(".symver __old_semctl,semctl@GLIBC_2.0");
#define semctl __old_semctl

// #include "old_sem.h"
void usage()
{
	puts("semtool [command] [arguments]")
	puts("  command: rmid [id]");
}
int main(int argc, char *argv[])
{
	int ret;
	int semid;

	while(argv++, --argc){
		if(strcmp(*argv, "rmid")==0 && argc==2){
			argv++, --argc;
			semid = atoi(*argv);
			semctl(semid, 0, IPR_RMID);
			return 0;
		// }else if(strcmp(*argv, "rmid")==0 && argc==2){
		}else{
			usage();
			exit(0);
		}
	}
	usage();
	exit(0);
	return 0;
}



