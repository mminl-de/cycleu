FILES ?= lib.zig
OUTPUT ?= libcycleu.so

install:
	zig build-lib $(FILES) --name $(OUTPUT) -Doptimize=ReleaseFast
debug:
	zig build-lib $(FILES) --name $(OUTPUT) 
