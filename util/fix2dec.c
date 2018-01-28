/* Converts list of fixed point numbers (fix32_16) supplied as command line 
 * arguments in radix 16 (hex) to their corresponding decimal notation.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main(int argc, char *argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Too few arguments.\n");
		exit(EXIT_FAILURE);
	}

	int i;
	uint32_t x;
	uint16_t frac;
	int16_t whole;

	for (i = 1; i < argc; i++) {
		x = (uint32_t)strtoul(argv[i], NULL, 16);
		whole = (int16_t)((x & 0xffff0000) >> 16);
		frac = x & 0x0000ffff;
		fprintf(stdout, "%f\n", whole + ((double)frac * 0.000015259));
	}

	exit(EXIT_SUCCESS);
}

