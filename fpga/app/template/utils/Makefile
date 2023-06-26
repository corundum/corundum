# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

PREFIX ?= /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin

CC ?= gcc
CFLAGS ?= -O3

CFLAGS += -Wall
CPPFLAGS += -Ilib -Iinclude
LDFLAGS += -Llib/mqnic
LDLIBS += -lmqnic

LIBMQNIC = lib/mqnic/libmqnic.a

BIN = app-template-test

GENDEPFLAGS = -MD -MP -MF .$(@F).d

ALL_CFLAGS = $(CFLAGS) $(CPPFLAGS) $(GENDEPFLAGS)

all: $(BIN)

FORCE:

$(LIBMQNIC): FORCE
	$(MAKE) -C $(dir $@) $(notdir $@)

%.o: %.c
	$(CC) $(ALL_CFLAGS) -c -o $@ $<

app-template-test: app-template-test.o $(LIBMQNIC)
	$(CC) $(ALL_CFLAGS) $(LDFLAGS) $^ -o $@ $(LDLIBS)

install:
	install -d $(BINDIR)
	install -m 0755 $(BIN) $(BINDIR)

clean:
	rm -f $(BIN)
	rm -f *.o
	rm -f .*.d

-include $(wildcard .*.d)

.PHONY: all install clean FORCE
