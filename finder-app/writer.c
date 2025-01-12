#include <stdio.h>
#include <syslog.h>

int main(int argc, char* argv[])
{
  openlog("Writer", LOG_PID, LOG_USER);

  if (argc != 3) {
    printf("There are expected 2 arguments: a file and a string\n");
    syslog(LOG_PERROR, "There are expected 2 arguments: a file and a string\n");
    return 1;
  };

  int return_code = 0;
  FILE *fp = fopen(argv[1], "wt");
  if (fp != NULL)
    {
        fputs(argv[2], fp);
        fclose(fp);
        syslog(LOG_DEBUG, "Writing %s to %s", argv[2], argv[1]);
        printf("Writing %s to %s\n", argv[2], argv[1]);
        return_code = 0;
    }
  else
    {
      printf("File open error (%s)\n", argv[1]);
      syslog(LOG_PERROR, "File open error (%s)", argv[1]);
      return_code = 1;
    }
  
  closelog();
  return return_code;
}
