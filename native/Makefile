CC := gcc
CFLAG := -g -fpic -I/usr/include/openssl11/
LDFLAG := -g -fpic -shared -lpthread -lluajit-5.1 -L/usr/lib64/openssl11/ -l:libssl.a -l:libcrypto.a
OBJS := beaver.o ctrl_io.o lua_api.o local_beaver.o async_ssl.o timer_io.o vsock.o
SO := liblbeaver.so

all: $(SO)

%.o: %.c
	$(CC) -c $< -o $@ $(CFLAG)

$(SO): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAG)

clean:
	rm -f $(SO) $(OBJS)