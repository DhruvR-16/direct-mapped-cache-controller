IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys

.PHONY: test synth reports clean

test:
	@mkdir -p build results traces
	@python3 analysis/generate_random_trace.py --mode read-random --seed 20261123 \
		--count 128 --output traces/random_read.trace
	@python3 analysis/generate_full_trace.py --output traces/full_project.trace
	@python3 analysis/cache_reference.py traces/full_project.trace \
		--output results/full_project_reference.json \
		--vectors results/full_project_vectors.txt
	@$(IVERILOG) -g2012 -Wall -s tb_direct_mapped_cache_phase2 -o build/cache_full_tb \
		rtl/cache_line_store.sv rtl/direct_mapped_cache.sv \
		tb/main_memory_model.sv tb/tb_direct_mapped_cache_phase2.sv
	@$(VVP) build/cache_full_tb +VECTORS=results/full_project_vectors.txt \
		+VCD=results/full_project.vcd +FULL_CHECKS > results/full_project.log
	@python3 -c "from pathlib import Path; lines = Path('results/full_project.log').read_text().splitlines(); print(next(line for line in lines if line.startswith('PROJECT SUMMARY trace ')))"
	@tail -n 9 results/full_project.log
	@$(MAKE) --no-print-directory synth
	@echo "PROJECT TEST PASSED - waveform: results/full_project.vcd"

synth:
	@mkdir -p results
	@$(YOSYS) -Q -T -l results/synthesis.log -p \
		'read_verilog -sv rtl/cache_line_store.sv rtl/direct_mapped_cache.sv; hierarchy -top direct_mapped_cache; synth -top direct_mapped_cache -flatten; stat' > /dev/null
	@python3 analysis/normalize_log.py results/synthesis.log
	@python3 -c "from pathlib import Path; log = Path('results/synthesis.log').read_text(); assert 'Found and reported 0 problems.' in log, 'Yosys design check failed'; print('SYNTHESIS CHECK PASSED: 0 problems')"

reports:
	tectonic -C -o report report/Direct_Mapped_Cache_Complete_IEEE_Report.tex

clean:
	python3 -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
