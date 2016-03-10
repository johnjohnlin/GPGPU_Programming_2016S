#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include "SyncedMemory.h"
#include "lab2.h"
using namespace std;

#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
	}\
}

int main(int argc, char **argv)
{
	Lab2VideoGenerator g;
	Lab2VideoInfo i;

	g.get_info(i);
	if (i.w == 0 or i.h == 0 or i.n_frame == 0 or i.fps_n == 0 or i.fps_d == 0) {
		puts("Cannot be zero");
		abort();
	} else if (i.w%2 != 0 or i.h%2 != 0) {
		puts("Only even frame size is supported");
		abort();
	}
	unsigned FRAME_SIZE = i.w*i.h*3/2;
	MemoryBuffer<uint8_t> frameb(FRAME_SIZE);
	auto frames = frameb.CreateSync(FRAME_SIZE);
	FILE *fp = fopen("result.y4m", "wb");
	fprintf(fp, "YUV4MPEG2 W%d H%d F%d:%d Ip A1:1 C420\n", i.w, i.h, i.fps_n, i.fps_d);

	for (unsigned j = 0; j < i.n_frame; ++j) {
		fputs("FRAME\n", fp);
		g.Generate(frames.get_gpu_wo());
		fwrite(frames.get_cpu_ro(), sizeof(uint8_t), FRAME_SIZE, fp);
	}

	fclose(fp);
	return 0;
}
