CC=gcc

all: ieee754 ieee754_hex

ieee754: ieee754.c
	$(CC) $(CFLAGS) -o ieee754 ieee754.c

ieee754_hex: ieee754_hex.c
	$(CC) $(CFLAGS) -o ieee754_hex ieee754_hex.c

.PHONY: clean

clean:
	rm -rf *.out ieee754
