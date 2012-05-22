/************************************************************
  Sample test icap server

	- Block access that URL contains "icapblock".
************************************************************/



#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

const char icap_server_name[] = "ICAP-TEST/1.0";

int icap_session(int as)
{
	FILE *fp_r=NULL, *fp_w=NULL;
	char icap_method[100]="";
	char client_ip[100]="";
	int func_ret = -1;
	char buf[1000];
	char *p, *p2;

	fp_r = fdopen(dup(as), "rb");
	if(fp_r==NULL){perror("fp_r"); exit(1);}
	fp_w = fdopen(dup(as), "wb");
	if(fp_w==NULL){perror("fp_w"); exit(1);}

	/*** get ICAP request line ***/
	if(fgets(buf, sizeof(buf), fp_r)==NULL){goto endlabel;}
	p = strchr(buf, ' ');
	if(p==NULL || p-buf >= sizeof(icap_method)){goto endlabel;}
	strncpy(icap_method, buf, p-buf);
	icap_method[p-buf] = '\0';

	/*** get ICAP request header ***/
	while(fgets(buf, sizeof(buf), fp_r)){
		p = strpbrk(buf, "\r\n");
		if(p){*p='\0';}
		if(buf[0]=='\0'){break;}
		if(strncasecmp(buf, "X-Client-IP: ", 13)==0 && strlen(buf+13)<sizeof(client_ip)){
			strcpy(client_ip, buf+13);
		}
	}

	printf("icap_method: [%s]\n", icap_method);

	if(strcmp(icap_method, "OPTIONS")==0){
		fprintf(fp_w, "ICAP/1.0 200 OK\r\n");
		fprintf(fp_w, "Connection: close\r\n");
		fprintf(fp_w, "Encapsulated: null-body=0\r\n");
		fprintf(fp_w, "Methods: REQMOD\r\n");
		fprintf(fp_w, "ISTag: %d\r\n", time(NULL));
		fprintf(fp_w, "Transfer-Complete: *\r\n");
		fprintf(fp_w, "Service: %s\r\n", icap_server_name);
		fprintf(fp_w, "Allow: 204\r\n");
		fprintf(fp_w, "\r\n");
	}else if(strcmp(icap_method, "REQMOD")==0){
		char http_method[100]="";
		char http_url[1000]="";
	
		/*** get HTTP request line ***/
		if(fgets(buf, sizeof(buf), fp_r)==NULL){goto endlabel;}
		p = strchr(buf, ' ');
		if(p==NULL || p-buf >= sizeof(http_method)){goto endlabel;}
		strncpy(http_method, buf, p-buf);
		http_method[p-buf] = '\0';

		p2 = p + 1;while(isspace(*p2)){p2++;}
		p = strchr(p2, ' ');
		if(p==NULL || p-p2 >= sizeof(http_url)){goto endlabel;}
		strncpy(http_url, p2, p-p2);
		http_method[p-p2] = '\0';

		printf("REQMOD: method=[%s], url=[%s], client_ip=[%s]\n", http_method, http_url, client_ip);

		if(strstr(http_url, "icapblock")){
			char http_resp_body[] = "<h1>Blocked</h1>";
			char http_resp_header[1000];

			snprintf(http_resp_header, sizeof(http_resp_header),
				"HTTP/1.0 200 OK\r\n"
				"Content-Type: text/html\r\n"
				"Content-Length: %d\r\n"
				"\r\n"
				, strlen(http_resp_body)
			);
			fprintf(fp_w, "ICAP/1.0 200 OK\r\n");
			fprintf(fp_w, "Encapsulated: res-hdr=0, res-body=%d\r\n", strlen(http_resp_header));
			fprintf(fp_w, "ISTag: %d\r\n", time(NULL));
			fprintf(fp_w, "Server: %s\r\n", icap_server_name);
			fprintf(fp_w, "Connection: close\r\n");
			fprintf(fp_w, "\r\n");
			fputs(http_resp_header, fp_w);
			fprintf(fp_w, "%x\r\n", strlen(http_resp_body));
			fputs(http_resp_body, fp_w);
			fprintf(fp_w, "\r\n0\r\n");
		}else{
			fprintf(fp_w, "ICAP/1.0 204 No Content\r\n");
			fprintf(fp_w, "Encapsulated: null-body=0\r\n");
			fprintf(fp_w, "ISTag: %d\r\n", time(NULL));
			fprintf(fp_w, "Server: %s\r\n", icap_server_name);
			fprintf(fp_w, "Connection: close\r\n");
			fprintf(fp_w, "\r\n");
		}
	}else{
		fprintf(fp_w, "ICAP/1.0 405 Method not allowed for service\r\n");
		fprintf(fp_w, "Encapsulated: null-body=0\r\n");
		fprintf(fp_w, "ISTag: %d\r\n", time(NULL));
		fprintf(fp_w, "Server: %s\r\n", icap_server_name);
		fprintf(fp_w, "Connection: close\r\n");
		fprintf(fp_w, "\r\n");
	}

	func_ret = 0;
endlabel:
	if(fp_r){fclose(fp_r);}
	if(fp_w){fclose(fp_w);}
	return func_ret;
}

int main(int argc, char *argv[])
{
	int listen_port = 1344;
	char listen_addrstr[100] = "127.0.0.1";
	int s;
	struct sockaddr_in sin;
	int val, ret;

	s = socket(AF_INET, SOCK_STREAM, 0);
	if(s==-1){perror("socket:"); exit(1);}

	val = 1;
	ret = setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val));
	if(ret==-1){perror("setsockopt(SO_REUSEADDR)"); exit(1);}

	sin.sin_family = AF_INET;
	sin.sin_port = htons(listen_port);
	sin.sin_addr.s_addr = inet_addr(listen_addrstr);
	ret = bind(s, (struct sockaddr*)&sin, sizeof(sin));
	if(ret==-1){perror("bind:"); exit(1);}

	ret = listen(s, 5);
	if(ret==-1){perror("listen:"); exit(1);}

	printf("listening %s:%d...\n", listen_addrstr, listen_port);

	while(1){
		struct sockaddr_in from;
		int fromlen = sizeof(from);
		int as;

		as = accept(s, (struct sockaddr*)&from, &fromlen);
		if(as==-1){perror("accept:"); exit(1);}

		printf("accepted\n");

		icap_session(as);

		close(as);
	}
	return 0;
}
