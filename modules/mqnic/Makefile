
# object files to build
obj-m += mqnic.o
mqnic-y += mqnic_main.o
mqnic-y += mqnic_dev.o
mqnic-y += mqnic_netdev.o
mqnic-y += mqnic_port.o
mqnic-y += mqnic_ptp.o
mqnic-y += mqnic_i2c.o
mqnic-y += mqnic_board.o
mqnic-y += mqnic_tx.o
mqnic-y += mqnic_rx.o
mqnic-y += mqnic_cq.o
mqnic-y += mqnic_eq.o
mqnic-y += mqnic_ethtool.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

