
CFLAGS=-Wall

all:	loxdiag

install: all
	install -m 755 loxdiag /usr/bin/loxdiag

loxdiag:	loxdiag.c fftsg.c
	cc -Wall loxdiag.c fftsg.c -o loxdiag -lasound -lm


