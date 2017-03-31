#include "lab1.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <algorithm>
#define maxStack 512
static const unsigned W = 960;
static const unsigned H = 960;
static const unsigned NFRAME = W;

typedef struct {
	int32_t l, r, pivotPos, rPos, pivot;
} Stack;

Stack stack[maxStack];
int stackF = -1;
uint32_t V[W];

uint32_t *bufferV;
Stack *bufferStack;

struct Lab1VideoGenerator::Impl {
	int t = 0;
};

Lab1VideoGenerator::Lab1VideoGenerator(): impl(new Impl) {
}

Lab1VideoGenerator::~Lab1VideoGenerator() {}

void Lab1VideoGenerator::get_info(Lab1VideoInfo &info) {
	info.w = W;
	info.h = H;
	info.n_frame = NFRAME;
	// fps = 24/1 = 24
	info.fps_n = 24;
	info.fps_d = 1;
};

void myStackPush(uint32_t l, uint32_t r, uint32_t pivotPos, uint32_t rPos, uint32_t pivot){	
	stackF++;
	stack[stackF].l = l;
	stack[stackF].r = r;
	stack[stackF].pivot = pivot;
	stack[stackF].pivotPos = pivotPos;
	stack[stackF].rPos = rPos;
}

void myPreprocessing(){
	srand(time(NULL));
	for (int i=0; i<W; i++)
		V[i] = i;
	std::random_shuffle(V, V+W);
	myStackPush(0, W-1, 0, W-1, V[0]);

	cudaMalloc(&bufferV, W*sizeof(uint32_t));
	cudaMalloc(&bufferStack, maxStack*sizeof(Stack));
}

void myQuickSort(){
	if (stackF < 0) return;
	int32_t l, r, pivot, pivotPos, rPos;
	l = stack[stackF].l;
	r = stack[stackF].r;
	pivot = stack[stackF].pivot;
	pivotPos = stack[stackF].pivotPos;
	rPos = stack[stackF].rPos;
	stackF--;

	if(l >= r) return;

	if (pivotPos >= rPos){
		myStackPush(l, pivotPos-1, l, pivotPos-1, V[l]);
		myStackPush(pivotPos+1, r, pivotPos+1, r, V[pivotPos+1]);
		return;
	}
	if (V[pivotPos+1] < pivot){
		V[pivotPos] = V[pivotPos+1];
		V[pivotPos+1] = pivot;
		pivotPos++;
	}
	else{
		int tmp = V[rPos];
		V[rPos] = V[pivotPos+1];
		V[pivotPos+1] = tmp;
		rPos--;
	}

	myStackPush(l, r, pivotPos, rPos, pivot);
}

__global__ void renderY(uint8_t *yuv, uint32_t *bufferV, int H, int stackF, Stack *bufferS){
	int x = blockIdx.x, y = threadIdx.x;
	int index = x * blockDim.x + y;
	uint8_t tmp;
	if (H-1-x > bufferV[y]) tmp = 0;
	else tmp = 255;
	for(int i=0; i<=stackF; i++)
		if (y/2 == bufferS[i].pivotPos/2 && H-1-x <= bufferS[i].pivot) tmp = 76;
	yuv[index] = tmp;
}

__global__ void renderU(uint8_t *yuv, uint32_t *bufferV, int H, int stackF, Stack *bufferS){
	int x = blockIdx.x, y = threadIdx.x;
	int index = x * blockDim.x + y;
	uint8_t tmp = 128;
	for(int i=0; i<=stackF; i++)
		if (y == bufferS[i].pivotPos/2 && (H-1-x)*2 <= bufferS[i].pivot) tmp = 85;
	yuv[index] = tmp;
}

__global__ void renderV(uint8_t *yuv, uint32_t *bufferV, int H, int stackF, Stack *bufferS){
	int x = blockIdx.x, y = threadIdx.x;
	int index = x * blockDim.x + y;
	uint8_t tmp = 128;
	for(int i=0; i<=stackF; i++)
		if (y == bufferS[i].pivotPos/2 && (H-1-x)*2 <= bufferS[i].pivot) tmp = 255;
	yuv[index] = tmp;
}

void Lab1VideoGenerator::Generate(uint8_t *yuv) {
	if (impl->t == 0)
		myPreprocessing();
	else
		for(int i=0; i<13; i++)
			myQuickSort();

	cudaMemcpy(bufferV, V, W*sizeof(uint32_t), cudaMemcpyHostToDevice);
	cudaMemcpy(bufferStack, stack, (stackF+2)*sizeof(Stack), cudaMemcpyHostToDevice);
	renderY<<<H, W>>>(yuv, bufferV, H, stackF, bufferStack);
	renderU<<<H/2, W/2>>>(yuv+W*H, bufferV, H/2, stackF, bufferStack);
	renderV<<<H/2, W/2>>>(yuv+W*H*5/4, bufferV, H/2, stackF, bufferStack);
	(impl->t)++;
}
