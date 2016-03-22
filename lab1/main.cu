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
tuple<vector<char>, vector<int>, vector<int>> GenerateTestCase(Engine &eng, const int N) {
	poisson_distribution<int> pd(14.0);
	bernoulli_distribution bd(0.1);
	uniform_int_distribution<int> id1(1, 20);
	uniform_int_distribution<int> id2(1, 5);
	uniform_int_distribution<int> id3('a', 'z');
	tuple<vector<char>, vector<int>, vector<int>> ret;
	auto &text = get<0>(ret);
	auto &pos = get<1>(ret);
	auto &head = get<2>(ret);
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
		head.push_back(text.size());
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

int main(int argc, char **argv)
{
	// Initialize random text
	default_random_engine engine(12345);
	auto text_pos_head = GenerateTestCase(engine, 40000000); // 40 MB data
	vector<char> &text = get<0>(text_pos_head);
	vector<int> &pos = get<1>(text_pos_head);
	vector<int> &head = get<2>(text_pos_head);

	// Prepare buffers
	int n = text.size();
	char *text_gpu;
	cudaMalloc(&text_gpu, sizeof(char)*n);
	SyncedMemory<char> text_sync(text.data(), text_gpu, n);
	text_sync.get_cpu_wo(); // touch the cpu data
	MemoryBuffer<int> pos_yours(n), head_yours(n);
	auto pos_yours_sync = pos_yours.CreateSync(n);
	auto head_yours_sync = head_yours.CreateSync(n);

	// Create timers
	Timer timer_count_position;

	// Part I
	timer_count_position.Start();
	int *pos_yours_gpu = pos_yours_sync.get_gpu_wo();
	cudaMemset(pos_yours_gpu, 0, sizeof(int)*n);
	CountPosition(text_sync.get_gpu_ro(), pos_yours_gpu, n);
	CHECK;
	timer_count_position.Pause();
	printf_timer(timer_count_position);

	// Part I check
	const int *golden = pos.data();
	const int *yours = pos_yours_sync.get_cpu_ro();
	int n_match1 = mismatch(golden, golden+n, yours).first - golden;
	if (n_match1 != n) {
		puts("Part I WA!");
		copy_n(golden, n, pos_yours_sync.get_cpu_wo());
	}

	// Part II
	int *head_yours_gpu = head_yours_sync.get_gpu_wo();
	cudaMemset(head_yours_gpu, 0, sizeof(int)*n);
	int n_head = ExtractHead(pos_yours_sync.get_gpu_ro(), head_yours_gpu, n);
	CHECK;

	// Part II check
	do {
		if (n_head != head.size()) {
			n_head = head.size();
			puts("Part II WA (wrong number of heads)!");
		} else {
			int n_match2 = mismatch(head.begin(), head.end(), head_yours_sync.get_cpu_ro()).first - head.begin();
			if (n_match2 != n_head) {
				puts("Part II WA (wrong heads)!");
			} else {
				break;
			}
		}
		copy_n(head.begin(), n_head, head_yours_sync.get_cpu_wo());
	} while(false);

	// Part III
	// Do whatever your want
	Part3(text_gpu, pos_yours_sync.get_gpu_rw(), head_yours_sync.get_gpu_rw(), n, n_head);
	CHECK;

	cudaFree(text_gpu);
	return 0;
}
