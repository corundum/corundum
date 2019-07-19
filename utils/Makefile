
PREFIX=/usr/local
BINDIR=$(DESTDIR)$(PREFIX)/bin

CC=gcc
CFLAGS=-O3 -Wall

BIN=mqnic-config mqnic-fw perout

all: $(BIN)

mqnic-config: mqnic-config.c
	$(CC) $(CFLAGS) $^ -o $@

mqnic-fw: mqnic-fw.c
	$(CC) $(CFLAGS) $^ -o $@

perout: perout.c
	$(CC) $(CFLAGS) $^ -o $@

install:
	install -d $(BINDIR)
	install -m 0755 $(BIN) $(BINDIR)

clean:
	rm -f $(BIN)

