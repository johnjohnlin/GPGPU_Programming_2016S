#include <random>
#include <vector>
#include <tuple>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <algorithm>
#include "SyncedMemory.h"
#include "Timer.h"
#include "counting.h"
using namespace std;

#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
	}\
}

template <typename Engine>
tuple<vector<char>, vector<int>> GenerateTestCase(Engine &eng, const int N) {
	poisson_distribution<int> pd(14.0);
	bernoulli_distribution bd(0.1);
	uniform_int_distribution<int> id1(1, 20);
	uniform_int_distribution<int> id2(1, 5);
	uniform_int_distribution<int> id3('a', 'z');
	tuple<vector<char>, vector<int>> ret;
	auto &text = get<0>(ret);
	auto &pos = get<1>(ret);
	auto gen_rand_word_len = [&] () -> int {
		return max(1, min(500, pd(eng) - 5 + (bd(eng) ? id1(eng)*20 : 0)));
	};
	auto gen_rand_space_len = [&] () -> int {
		return id2(eng);
	};
	auto gen_rand_char = [&] () {
		return id3(eng);
	};
	auto AddWord = [&] () {
		int n = gen_rand_word_len();
		for (int i = 0; i < n; ++i) {
			text.push_back(gen_rand_char());
			pos.push_back(i+1);
		}
	};
	auto AddSpace = [&] () {
		int n = gen_rand_space_len();
		for (int i = 0; i < n; ++i) {
			text.push_back('\n');
			pos.push_back(0);
		}
	};

	AddWord();
	while (text.size() < N) {
		AddSpace();
		AddWord();
	}
	return ret;
}

void TestRoutine(
	SyncedMemory<int>& yours_sync, SyncedMemory<char>& text_sync,
	const int n, const int part, const int *golden
) {
	// Initialization
	Timer timer_count_position;
	int *yours_gpu = yours_sync.get_gpu_wo();
	cudaMemset(yours_gpu, 0, sizeof(int)*n);

	// Run
	timer_count_position.Start();
	if (part == 1) {
		CountPosition1(text_sync.get_gpu_ro(), yours_gpu, n);
	} else {
		CountPosition2(text_sync.get_gpu_ro(), yours_gpu, n);
	}
	CHECK;
	timer_count_position.Pause();

	// Part I check
	const int *yours = yours_sync.get_cpu_ro();
	int n_match = mismatch(golden, golden+n, yours).first - golden;

	printf_timer(timer_count_position);
	if (n_match != n) {
		printf("Part %d WA\n", part);
	} else {
		printf("Part %d AC\n", part);
	}
}
#define KB <<10
#define MB <<20
int main(int argc, char **argv)
{
	// Initialize random text
	default_random_engine engine(12345);
	auto text_pos_head = GenerateTestCase(engine, 40 MB);
	vector<char> &text = get<0>(text_pos_head);
	vector<int> &pos = get<1>(text_pos_head);

	// Prepare buffers
	int n = text.size();
	char *text_gpu;
	cudaMalloc(&text_gpu, sizeof(char)*n);
	SyncedMemory<char> text_sync(text.data(), text_gpu, n);
	text_sync.get_cpu_wo(); // touch the cpu data
	MemoryBuffer<int> yours1_buf(n);
	MemoryBuffer<int> yours2_buf(n);
	auto yours1_mb = yours1_buf.CreateSync(n);
	auto yours2_mb = yours2_buf.CreateSync(n);

	// We test 2 in first to prevent cheating
	TestRoutine(yours1_mb, text_sync, n, 2, pos.data());
	TestRoutine(yours2_mb, text_sync, n, 1, pos.data());

	cudaFree(text_gpu);
	return 0;
}
