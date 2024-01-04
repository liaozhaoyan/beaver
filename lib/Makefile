CC := gcc
AR := ar
CFLAG := -g -I../native
OBJS := entry.o
LIB := libbeaver.a

all: $(LIB)

%.o: %.c
	$(CC) -c $< -o $@ $(CFLAG)

$(LIB): $(OBJS)
	$(AR) cr $@ $(OBJS)

clean:
	rm -f $(EXEC) $(OBJS)