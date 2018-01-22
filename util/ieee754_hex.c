/* Converts list of decimal numbers supplied as command line arguments 
 * to their corresponding double precision floating point 
 * representation (IEEE-754).
 */

#include <stdio.h>
#include <stdlib.h>

typedef union {
	unsigned long long int i;
	double f;
} U;

int main(int argc, char *argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Too few arguments.\n");
		exit(EXIT_FAILURE);
	}

	U u;
	int i;

	for (i = 1; i < argc; i++) {
		u.i = strtoull(argv[i], NULL, 16);
		fprintf(stdout, "%e\n", u.f);
	}

	exit(EXIT_SUCCESS);
}

