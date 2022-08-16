PEEK = peek
POKE = poke

# Add any other object files to this list below
PEEK_OBJS = peek.o
POKE_OBJS = poke.o

all: $(PEEK) $(POKE)

$(POKE): $(POKE_OBJS)
	$(CC) $(LDFLAGS) -o $@ $(POKE_OBJS) $(LDLIBS)

$(PEEK): $(PEEK_OBJS)
	$(CC) $(LDFLAGS) -o $@ $(PEEK_OBJS) $(LDLIBS)

clean:
	-rm -f $(POKE) $(PEEK) *.elf *.gdb *.o


