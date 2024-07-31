CC := gcc
CFLAG := -g -I../lib
LDFLAG := -g -L../lib -lbeaver -L../native -llbeaver -L/usr/lib64/ -ltcmalloc -lz -lpthread
# LDFLAG := -g -L../lib -lbeaver -L../native -llbeaver -L/usr/lib64/ -lz -lpthread
OBJS := main.o
EXEC := main

all: $(EXEC)

%.o: %.c
	$(CC) -c $< -o $@ $(CFLAG)

$(EXEC): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAG)

clean:
	rm -f $(SO) $(OBJS)