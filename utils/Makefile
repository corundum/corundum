
PREFIX=/usr/local
BINDIR=$(DESTDIR)$(PREFIX)/bin

CC=gcc
CFLAGS=-O3 -Wall -I../modules/mqnic

BIN=mqnic-config mqnic-dump mqnic-fw perout

all: $(BIN)

mqnic-config: mqnic-config.c mqnic.c timespec.c
	$(CC) $(CFLAGS) $^ -o $@

mqnic-dump: mqnic-dump.c mqnic.c
	$(CC) $(CFLAGS) $^ -o $@

mqnic-fw: mqnic-fw.c mqnic.c
	$(CC) $(CFLAGS) $^ -o $@

perout: perout.c timespec.c
	$(CC) $(CFLAGS) $^ -o $@

install:
	install -d $(BINDIR)
	install -m 0755 $(BIN) $(BINDIR)

clean:
	rm -f $(BIN)

