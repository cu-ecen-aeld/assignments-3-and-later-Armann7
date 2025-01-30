#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define PORT 9000
#define BACKLOG 5
#define DATA_FILENAME "/var/tmp/aesdsocketdata"
#define CHUNK_SIZE 1024
#define BUFFER_SIZE 65535


int is_receive_signal = 0;


void handle_signal(int signal) {
    if (signal == SIGINT || signal == SIGTERM) {
		syslog(LOG_INFO, "Caught signal, exiting");        
        is_receive_signal = 1;
    }
}


int file_append(char *data) {
    FILE *file = fopen(DATA_FILENAME, "a");
	if (file == NULL) {
		syslog(LOG_PERROR, "Error opening file");
    	return -1;
	}
    if (fprintf(file, "%s", data) < 0) {
		syslog(LOG_PERROR, "Error writing to file");
        fclose(file);
        return -1;
    }
    fclose(file);
    return 0;
}


int send_data(int socket) {
	char buffer[CHUNK_SIZE];
    size_t bytes_read;

    FILE *file = fopen(DATA_FILENAME, "r");
	if (file == NULL) {
		syslog(LOG_PERROR, "Error opening file");
    	return -1;
	}

    while ((bytes_read = fread(buffer, 1, CHUNK_SIZE, file)) > 0) {
        buffer[bytes_read] = '\0';
	    if (send(socket, &buffer, bytes_read, 0) == -1) {
			syslog(LOG_PERROR, "Error sending data");
    		fclose(file);
	        return -1;
	    }
    }

    fclose(file);
    return 0;
}


int main() {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    int opt = 1;
    int client_addrlen = sizeof(client_addr);
    char client_ip[INET_ADDRSTRLEN];
    char buffer[BUFFER_SIZE] = {0};
    struct sigaction sa;
    
    pid_t pid = fork();
    if (pid < 0) {
        exit(-1);
    }
    if (pid > 0) {
        exit(0);
    }

	openlog("aesdsocket", LOG_PID, LOG_USER);

    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGTERM, &sa, NULL) == -1) {
		syslog(LOG_PERROR, "Error setting SIGTERM handler");
		closelog();
        exit(-1);
    }
    if (sigaction(SIGINT, &sa, NULL) == -1) {
		syslog(LOG_PERROR, "Error setting SIGINT handler");
		closelog();
        exit(-1);
    }

    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
		syslog(LOG_PERROR, "Socket failed");
		closelog();
        exit(-1);
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(PORT);
    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
		syslog(LOG_PERROR, "Bind failed");
        close(server_fd);
        closelog();
        exit(-1);
    }

    if (listen(server_fd, BACKLOG) < 0) {
		syslog(LOG_PERROR, "Listen failed");
        close(server_fd);
        closelog();
        exit(-1);
    }

    while (1) {
    	ssize_t bytes_received = 0;
	    if ((client_fd = accept(server_fd, (struct sockaddr *)&client_addr, (socklen_t *)&client_addrlen)) >= 0) {
		    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
		    syslog(LOG_INFO, "Accepted connection from %s", client_ip);
		    bytes_received = recv(client_fd, (void*)&buffer, BUFFER_SIZE, 0);
		    if (bytes_received < 0) {
		    	syslog(LOG_PERROR, "Error on read data");
		        close(server_fd);
		        close(client_fd);
		        closelog();
		        exit(-1);
		    }
		    if (bytes_received == 0) {
		    	syslog(LOG_PERROR, "Connection was closed");
		        close(server_fd);
		        close(client_fd);
		        closelog();
		        exit(-1);
		    }
		    if (buffer[bytes_received-1] != '\n') {
		    	buffer[bytes_received] = '\n';
		    	bytes_received++;
		    }
		    buffer[bytes_received] = '\0';
	    } else
	    	close(server_fd);

	    if (bytes_received > 0) {
		    if (file_append(&buffer[0]) != 0) {
		    	syslog(LOG_PERROR, "Failed to append data to %s", DATA_FILENAME);
		        close(server_fd);
		        close(client_fd);
		        closelog();
		        exit(-1);	    	
		    }
		
			if (send_data(client_fd) != 0) {
		    	syslog(LOG_PERROR, "Failed to send data");
		        close(server_fd);
		        close(client_fd);
		        closelog();
		        exit(-1);	    	
		    }
		    syslog(LOG_INFO, "Closed connection from %s", client_ip);
		}

	    if (is_receive_signal != 0) {
	    	unlink(DATA_FILENAME);
        	printf("Finished\n");
		    closelog();
	    	exit(0);
	    }
	}
}
