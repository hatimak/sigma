CC=gcc
CFLAGS=-Wall

all: ieee754 ieee754_hex fix2dec

ieee754: ieee754.c
	$(CC) $(CFLAGS) -o ieee754 ieee754.c

ieee754_hex: ieee754_hex.c
	$(CC) $(CFLAGS) -o ieee754_hex ieee754_hex.c

fix2dec: fix2dec.c
	$(CC) $(CFLAGS) -o fix2dec fix2dec.c

.PHONY: clean

clean:
	rm -rf *.out ieee754 ieee754_hex fix2dec
