#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>  //sockaddr_in

int send_response(FILE *fp_w, char *url)
{
  FILE *fp_file;
  char buf[10000];

  fp_file = fopen(url,"rb");
  if(fp_file==NULL){
    perror("fopen:");
    fprintf(fp_w,"HTTP/1.0 404 Not Found\r\n");
    fprintf(fp_w,"\r\n");
    fprintf(fp_w,"can't find url[%s]\n",url);
  }else{
    int n;
    fprintf(fp_w,"HTTP/1.0 200 OK\r\n");
    fprintf(fp_w,"\r\n");
    while((n=fread(buf, 1, sizeof(buf),fp_file))>0){
      fwrite(buf,1,n,fp_w);
    }
    fclose(fp_file);
  }
}
int http_session(int sc)
{
  FILE *fp_r,*fp_w;
  char buf[10000]="buffer";
  char url[10000]="test";
  int ret;
  
  fp_r = fdopen(sc, "rb");
  if(fp_r==NULL){perror("fdopen_r:");exit(1);}
  fp_w = fdopen(sc, "wb");
  if(fp_w==NULL){perror("fdopen_w:");exit(1);}

  fgets(buf, sizeof(buf),fp_r);
  ret = sscanf(buf,"GET %s",url);
  while(fgets(buf, sizeof(buf),fp_r)!=NULL && buf[0]!='\n' && buf[0] != '\r'){
    ;
  }
  // printf("url=[%s]\n",url);
  send_response(fp_w, url);
  fclose(fp_w);
  fclose(fp_r);
  close(sc);
}
int main(int argc, char*argv[])
{
	int port = 12345;
	int s;
	int ret;
	struct sockaddr_in sin;
	int val;

	s = socket(AF_INET, SOCK_STREAM,0);
	if(s<0){perror("socket:");exit(1);}

	val = 1;
	ret = setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &val,sizeof(val));
	if(ret<0){perror("setsockopt:");exit(1);}

	sin.sin_family = AF_INET;
	sin.sin_port = htons(port);
	sin.sin_addr.s_addr = INADDR_ANY;
	ret = bind(s, (struct sockaddr*)&sin, sizeof(sin));
	if(ret<0){perror("bind:");exit(1);}

	ret = listen(s, 5);
	if(ret<0){perror("listen:");exit(1);}

	while(1){
		int sc;
		struct sockaddr_in from;
		int fromlen = sizeof(from);

		sc = accept(s, (struct sockaddr*)&from, &fromlen);
		if(sc<0){perror("accept:");exit(1);}
		http_session(sc);
	}
}


