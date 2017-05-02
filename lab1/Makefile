INCLUDES=../utils
CXXFLAGS=-std=c++11 -Wno-deprecated-gpu-targets

all: main

main: main.cu lab1.cu
	nvcc -I$(INCLUDES) $(CXXFLAGS) main.cu lab1.cu -o main

clean:
	rm main result.*
