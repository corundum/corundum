
# object files to build
obj-m += mqnic.o
mqnic-objs += mqnic_main.o mqnic_dev.o mqnic_netdev.o mqnic_port.o mqnic_ethtool.o mqnic_i2c.o mqnic_ptp.o mqnic_tx.o mqnic_rx.o mqnic_cq.o mqnic_eq.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

