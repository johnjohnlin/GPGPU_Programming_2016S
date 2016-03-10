#pragma once
#include <cstdint>
#include <memory>
using std::unique_ptr;

struct Lab2VideoInfo {
	unsigned w, h, n_frame;
	unsigned fps_n, fps_d;
};

class Lab2VideoGenerator {
	struct Impl;
	unique_ptr<Impl> impl;
public:
	Lab2VideoGenerator();
	~Lab2VideoGenerator();
	void get_info(Lab2VideoInfo &info);
	void Generate(uint8_t *yuv);
};
