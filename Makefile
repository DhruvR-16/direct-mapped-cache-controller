IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys

.PHONY: test synth clean

test:
	mkdir -p build results
	$(IVERILOG) -g2012 -Wall -s tb_direct_mapped_cache -o build/cache_tb \
		rtl/cache_line_store.sv rtl/direct_mapped_cache.sv \
		tb/main_memory_model.sv tb/tb_direct_mapped_cache.sv
	$(VVP) build/cache_tb > results/simulation.log
	cat results/simulation.log

synth:
	mkdir -p results
	$(YOSYS) -Q -T -l results/synthesis.log -p \
		'read_verilog -sv rtl/cache_line_store.sv rtl/direct_mapped_cache.sv; hierarchy -top direct_mapped_cache; synth -top direct_mapped_cache -flatten; stat' > /dev/null
	tail -n 40 results/synthesis.log

clean:
	rm -rf build results/cache.vcd results/simulation.log results/synthesis.log
