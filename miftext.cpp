#include <stdio.h>
#include <stdlib.h>

void miftext(FILE *in, FILE *out);

int main(int argc, char *argv[])
{
	char *filename;

	if (argc<3) {
		printf("usage: miftext input_file output_file\n");
		return -1;
	}

	FILE *in, *out;
	errno_t err;
	filename = argv[1];
	err = fopen_s(&in,filename,"rt");
	if (err) {
		printf("file: %s not found\n",filename);
		return -1;
	}
	filename = argv[2];
	err = fopen_s(&out,filename,"wt");
	if (err) {
		printf("file: %s not opened\n",filename);
		return -1;
	}
	miftext(in,out);
	return 0;
}

void miftext(FILE *in, FILE *out)
{
	unsigned int data;
	unsigned int address, offset;
	unsigned int ndepth = 256;
	int nwidth = 8;
	fprintf(out,"DEPTH = %d;\n",ndepth);
	fprintf(out,"WIDTH = %d;\n\n",nwidth);
	fprintf(out,"ADDRESS_RADIX = HEX;\n");
	fprintf(out,"DATA_RADIX = HEX;\n");
	fprintf(out,"CONTENTS\n  BEGIN\n");
	fprintf(out,"[0..%x]   :  0;\n",ndepth-1);
	address = 0;
	offset = 0;
	while ( ( data = getc( in ) ) != EOF ) {
		if (data=='\n') {
			while (offset<16) {
				fprintf(out,"%04x : %02x;\n",address,' ');
				address++;
				offset++;
			}
			offset = 0;
		}
		else {
			fprintf(out,"%04x  : %02x; %% %c %%\n",address,data,(data<32?32:data));
			address++;
			offset++;
		}
		if (address>=ndepth) break;
	}
	fprintf(out,"END;\n");
	fclose(in);
	fclose(out);
}
