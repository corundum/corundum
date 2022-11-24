
PREFIX ?= /usr/local
INCDIR = $(DESTDIR)$(PREFIX)/include
LIBDIR = $(DESTDIR)$(PREFIX)/lib
DEVLIBDIR = $(LIBDIR)

CC ?= gcc
CFLAGS ?= -O3 -fPIC

CFLAGS += -Wall
CPPFLAGS += 

LIB = libmqnic.a
INCLUDES = mqnic.h mqnic_hw.h mqnic_ioctl.h reg_if.h reg_block.h fpga_id.h

GENDEPFLAGS = -MD -MP -MF .$(@F).d

ALL_CFLAGS = $(CFLAGS) $(CPPFLAGS) $(GENDEPFLAGS)

all: $(LIB)

%.o: %.c
	$(CC) $(ALL_CFLAGS) -c -o $@ $<

libmqnic.a: mqnic.o mqnic_if.o mqnic_port.o mqnic_sched_block.o mqnic_scheduler.o mqnic_clk_info.o mqnic_stats.o reg_if.o reg_block.o fpga_id.o
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
