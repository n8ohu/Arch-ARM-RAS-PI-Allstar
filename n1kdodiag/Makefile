
CFLAGS=-Wall

all:	n1kdodiag

install: all
	install -m 755 n1kdodiag /usr/bin/n1kdodiag

n1kdodiag:	n1kdodiag.c fftsg.c
	cc -Wall n1kdodiag.c fftsg.c -o n1kdodiag -lusb -lasound -lm

clean:
	rm -f n1kdodiag
