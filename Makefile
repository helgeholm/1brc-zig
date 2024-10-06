1brc:
	zig build -Doptimize=ReleaseFast

stat: 1brc
	perf stat -B -e cache-references,branches,cache-misses,cycles ./zig-out/bin/1brc

perf: 1brc
	perf record -F 99 -B -e cache-references,branches,cache-misses,cycles ./zig-out/bin/1brc
	perf report --stdio
	
time: 1brc
	/bin/time -v ./zig-out/bin/1brc

