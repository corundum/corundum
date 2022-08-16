/*
* peek utility - for those who remember the good old days!
*
*
* Copyright (C) 2013 - 2016  Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without restriction,
* including without limitation the rights to use, copy, modify, merge,
* publish, distribute, sublicense, and/or sell copies of the Software,
* and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
* CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in this
* Software without prior written authorization from Xilinx.
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

void usage(char *prog)
{
	printf("usage: %s ADDR\n",prog);
	printf("\n");
	printf("ADDR may be specified as hex values\n");
}


int main(int argc, char *argv[])
{
	int fd;
	void *ptr;
	unsigned addr, page_addr, page_offset;
	unsigned page_size=sysconf(_SC_PAGESIZE);

	if(argc!=2) {
		usage(argv[0]);
		exit(-1);
	}

	fd=open("/dev/mem",O_RDONLY);
	if(fd<1) {
		perror(argv[0]);
		exit(-1);
	}

	addr=strtoul(argv[1],NULL,0);
	page_addr=(addr & ~(page_size-1));
	page_offset=addr-page_addr;

	ptr=mmap(NULL,page_size,PROT_READ,MAP_SHARED,fd,(addr & ~(page_size-1)));
	if((int)ptr==-1) {
		perror(argv[0]);
		exit(-1);
	}

	printf("0x%08x\n",*((unsigned *)(ptr+page_offset)));
	return 0;
}


