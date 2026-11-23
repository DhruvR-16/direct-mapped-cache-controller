IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys

.PHONY: test phase2-test synth phase2-reference reports clean

test:
	mkdir -p build results
	$(IVERILOG) -g2012 -Wall -s tb_direct_mapped_cache -o build/cache_tb \
		rtl/cache_line_store.sv rtl/direct_mapped_cache.sv \
		tb/main_memory_model.sv tb/tb_direct_mapped_cache.sv
	$(VVP) build/cache_tb +VCD=results/phase1_regression.vcd > results/phase1_regression.log
	cat results/phase1_regression.log

synth:
	mkdir -p results
	$(YOSYS) -Q -T -l results/synthesis.log -p \
		'read_verilog -sv rtl/cache_line_store.sv rtl/direct_mapped_cache.sv; hierarchy -top direct_mapped_cache; synth -top direct_mapped_cache -flatten; stat' > /dev/null
	@if test -f analysis/normalize_log.py; then python3 analysis/normalize_log.py results/synthesis.log; fi
	tail -n 40 results/synthesis.log

phase2-reference:
	mkdir -p results
	@if test -f analysis/cache_reference.py; then \
		python3 analysis/cache_reference.py traces/phase2_smoke.trace \
			--output results/phase2_reference.json --vectors results/phase2_vectors.txt; \
	fi
	@test -s results/phase2_vectors.txt

phase2-test: phase2-reference
	mkdir -p build results
	$(IVERILOG) -g2012 -Wall -s tb_direct_mapped_cache_phase2 -o build/cache_phase2_tb \
		rtl/cache_line_store.sv rtl/direct_mapped_cache.sv \
		tb/main_memory_model.sv tb/tb_direct_mapped_cache_phase2.sv
	$(VVP) build/cache_phase2_tb +VECTORS=results/phase2_vectors.txt \
		+VCD=results/phase2_smoke.vcd +SMOKE > results/phase2_smoke.log
	@if test -f analysis/cache_reference.py; then \
		python3 analysis/cache_reference.py traces/phase2_random.trace \
			--output results/phase2_random_reference.json --vectors results/phase2_random_vectors.txt; \
	fi
	@test -s results/phase2_random_vectors.txt
	$(VVP) build/cache_phase2_tb +VECTORS=results/phase2_random_vectors.txt \
		+VCD=results/phase2_random.vcd > results/phase2_random.log
	python3 analysis/generate_random_trace.py --mode read-random --seed 20261123 \
		--count 128 --output traces/random_read.trace
	@if test -f analysis/cache_reference.py; then \
		python3 analysis/cache_reference.py traces/random_read.trace \
			--output results/random_read_reference.json --vectors results/random_read_vectors.txt; \
	fi
	@test -s results/random_read_vectors.txt
	$(VVP) build/cache_phase2_tb +VECTORS=results/random_read_vectors.txt \
		+VCD=results/random_read.vcd > results/random_read.log
	tail -n 6 results/phase2_smoke.log
	tail -n 4 results/phase2_random.log
	tail -n 4 results/random_read.log

reports:
	tectonic -C -o report report/Direct_Mapped_Cache_Complete_IEEE_Report.tex

clean:
	python3 -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
