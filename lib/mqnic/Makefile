
PREFIX ?= /usr/local
INCDIR = $(DESTDIR)$(PREFIX)/include
LIBDIR = $(DESTDIR)$(PREFIX)/lib
DEVLIBDIR = $(LIBDIR)

CC ?= gcc
CFLAGS ?= -O3 -fPIC

CFLAGS += -Wall
CPPFLAGS += 

LIB = libmqnic.a
INCLUDES = mqnic.h mqnic_hw.h mqnic_ioctl.h reg_block.h

GENDEPFLAGS = -MD -MP -MF .$(@F).d

ALL_CFLAGS = $(CFLAGS) $(CPPFLAGS) $(GENDEPFLAGS)

all: $(LIB)

%.o: %.c
	$(CC) $(ALL_CFLAGS) -c -o $@ $<

libmqnic.a: mqnic.o mqnic_if.o mqnic_sched_block.o mqnic_scheduler.o reg_block.o
	ar rcs $@ $^

install:
	install -d $(DEVLIBDIR) $(INCDIR)/mqnic
	install -m 0644 $(LIB) $(DEVLIBDIR)
	install -m 0644 $(INCLUDES) $(INCDIR)/mqnic

clean:
	rm -f $(LIB)
	rm -f *.o
	rm -f .*.d

-include $(wildcard .*.d)

.PHONY: all install clean
