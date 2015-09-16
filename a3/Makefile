VFILES=$(wildcard *.v)

cpu : $(VFILES) Makefile
	iverilog  -o cpu $(VFILES)

run : cpu
	timeout 10 ./cpu

clean :
	rm -rf cpu

test : cpu
	@timeout 10 ./cpu > test.raw 2>&1
	@egrep "^#" test.raw > test.out
	@egrep "^@" test.raw > test.cycles
	@((diff -b test.out test.ok > /dev/null 2>&1) && echo "pass `cat test.cycles`") || (echo "fail" ; echo "\n\n----------- expected ----------"; cat test.ok ; echo "\n\n------------- found ----------"; cat test.out)
