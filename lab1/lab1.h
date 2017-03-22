#pragma once
#include <cstdint>
#include <memory>
using std::unique_ptr;

struct Lab1VideoInfo {
	unsigned w, h, n_frame;
	unsigned fps_n, fps_d;
};

class Lab1VideoGenerator {
	struct Impl;
	unique_ptr<Impl> impl;
public:
	Lab1VideoGenerator();
	~Lab1VideoGenerator();
	void get_info(Lab1VideoInfo &info);
	void Generate(uint8_t *yuv);
};
