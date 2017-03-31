#include "lab1.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <algorithm>
static const unsigned W = 960;
static const unsigned H = 960;
static const unsigned NFRAME = W;

uint32_t V[W];
uint8_t T[H*W*3/2];

typedef struct {
	uint32_t l, r, pivotPos, rPos, pivot;
} Stack;

Stack stack[512];
int stackF = -1;

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
}

void myQuickSort(){
	if (stackF < 0) return;
	unsigned int l, r, pivot, pivotPos, rPos;
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

void Lab1VideoGenerator::Generate(uint8_t *yuv) {
	if (impl->t == 0)
		myPreprocessing();
	else
		for(int i=0; i<13; i++)
			myQuickSort();

	// Render
	for (int i=0; i<H; i++){
		for (int j=0; j<W; j++){
			if (H-1-i > V[j]) T[i*W+j] = 0;
			else T[i*W+j] = 255;
		}
		for (int j=0; j<=stackF; j++)
			if (H-1-i <= stack[j].pivot)
				T[i*W + stack[j].pivotPos] = 76;
	}

	for (int i=0; i<H/2; i++){
		for (int j=0; j<W/2; j++)
			T[W*H + i*W/2 + j] = 128;
		for (int j=0; j<=stackF; j++)
			if (H-1-i*2 <= stack[j].pivot)
				T[W*H + i*W/2 + stack[j].pivotPos/2] = 85;
	}

	for (int i=0; i<H/2; i++){
		for (int j=0; j<W/2; j++)
			T[W*H*5/4 + i*W/2 + j] = 128;
		for (int j=0; j<=stackF; j++)
			if (H-1-i*2 <= stack[j].pivot)
				T[W*H*5/4 + i*W/2 + stack[j].pivotPos/2] = 255;
	}

	cudaMemcpy(yuv, T, W*H*3/2, cudaMemcpyHostToDevice);
	(impl->t)++;
}
