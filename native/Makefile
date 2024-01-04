CC := gcc
CFLAG := -g -fpic
LDFLAG := -g -fpic -shared -lssl -lcrypto -lpthread -lluajit-5.1
OBJS := beaver.o ctrl_io.o lua_api.o local_beaver.o async_ssl.o
SO := liblbeaver.so

all: $(SO)

%.o: %.c
	$(CC) -c $< -o $@ $(CFLAG)

$(SO): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAG)

clean:
	rm -f $(SO) $(OBJS)