#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define X 38
#define Y 32

int main(void) {
	uint8_t inbuf[16384], *ptr = inbuf;
	uint8_t outbuf[16384] = {0};
	uint8_t max[2] = {0};
	int len;
	len = fread(inbuf, 1, sizeof inbuf, stdin);
	fprintf (stderr, "len=%d\n", len);

	for (int i=0; i<X*Y; i++) {
		uint8_t nlayers = *ptr++;
		assert (nlayers==1 || nlayers==2);
		for (int n=0; n<nlayers; n++) {
			uint16_t sq = ptr[0] + (ptr[1]<<8);
			assert (sq < 256);
			ptr+=2;
			outbuf[i*2+n] = sq;
			if (sq > max[n]) max[n] = sq;
		}
	}
	assert (ptr == &inbuf[len]);
	fprintf (stderr, "max: %02x %02x\n", max[0], max[1]);
	fwrite (outbuf, 1, X*Y*2, stdout);
	return 0;
}
