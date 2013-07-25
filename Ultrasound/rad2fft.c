#include <stdlib.h>
#include <math.h>
#include "rad2fft.h"

#define CplxMul32Packed(x,p) { \
	int tmp = x.real; int c = (p) & 0xffff0000; int s = ((p)<<16); \
	x.real = (int)( ( (int64_t)tmp * (int64_t)c - (int64_t)x.imag * (int64_t)s ) >> 32 ); \
	x.imag = (int)( ( (int64_t)tmp * (int64_t)s + (int64_t)x.imag * (int64_t)c ) >> 32 ); \
} \

#define Radix2IntButterfly(x0,x1,n) { \
	int tmp = x0.real>>1; \
	x0.real = tmp + (x1.real>>n);\
	x1.real = tmp - (x1.real>>n);\
	tmp = (x0.imag>>1); \
	x0.imag = tmp + (x1.imag>>n);\
	x1.imag = tmp - (x1.imag>>n);\
} \

static int FloatToInt16(float x)
{
	int y;
	if(x<0.f) {
		if(x<=-32768.0f) y = -32768;
		else y = (int)(x - 0.5f);
	} else {
		if(x>=32767.0f) y = 32767;
		else y = (int)(x + 0.5f);		
	}
	return y;
}


static void BitReverseReorder(Int32Cplx* ioCplxData, int N)
{
	int linearIdx, bitReversedIdx;

	for(linearIdx = 1, bitReversedIdx = 0; linearIdx < N - 1; ++linearIdx) {
		int halfSize = N;
		do {
			halfSize >>=1;
			bitReversedIdx ^= halfSize;
		} while(bitReversedIdx < halfSize);

		if(linearIdx < bitReversedIdx) {
			/* Swap linear and bit reversed indexed values */
			Int32Cplx tmp = ioCplxData[bitReversedIdx];
			ioCplxData[bitReversedIdx] = ioCplxData[linearIdx];
			ioCplxData[linearIdx] = tmp;
		}
	}
}


PackedInt16Cplx* CreatePackedTwiddleFactors(int size)
{
	int i;
	PackedInt16Cplx* twiddleFactors = (PackedInt16Cplx*)malloc(sizeof(PackedInt16Cplx)*size);
	float scaleFac = (float)(1<<15);

	if(twiddleFactors) {
		for(i = 0; i < size/2; ++i) {
			int cosSin;
			float tmp;
			tmp = scaleFac*cosf(2.0*M_PI*i/size);
			cosSin = FloatToInt16(tmp) << 16;
			tmp = -scaleFac*sinf(2.0*M_PI*i/size);
			cosSin |= FloatToInt16(tmp) & 0x0000ffff;
			twiddleFactors[i] = cosSin;
		}
	}
	return twiddleFactors;
}


void DisposePackedTwiddleFactors(PackedInt16Cplx* twiddleFactors)
{
	if(twiddleFactors) {
		free(twiddleFactors);
	}
}


void Radix2IntCplxFFT(Int32Cplx* ioCplxData, int size, const PackedInt16Cplx* twiddleFactors, int twiddleFactorsStrides)
{
	int span, twiddle, strides;

	/* Reorder input data in bit reversed order */
	BitReverseReorder(ioCplxData, size);

	span = 1;
	twiddle = 1;
	strides = twiddleFactorsStrides*size / 2;
	
	do {
		Int32Cplx x0, x1;
		int idx = 0;

		do {
			/* Multiply-less butterfly */
			x1 = ioCplxData[idx+span];
			x0 = ioCplxData[idx];
			Radix2IntButterfly(x0, x1, 1);
			ioCplxData[idx] = x0;
			ioCplxData[idx+span] = x1;
			idx += span << 1;
		} while(idx < size);

		twiddle = 1;
		
		while(twiddle < span) {
			int packedTwiddleFactor = twiddleFactors[strides*twiddle];
			idx = twiddle;
			
			do {
				x1 = ioCplxData[idx+span];
				x0 = ioCplxData[idx];
				CplxMul32Packed(x1, packedTwiddleFactor);
				Radix2IntButterfly(x0, x1, 0);
				ioCplxData[idx] = x0;
				ioCplxData[idx+span] = x1;
				idx += span << 1;
			} while(idx < size);
			++twiddle;
		}
		span <<= 1;
		strides >>= 1;		
	} while(span < size);
}
