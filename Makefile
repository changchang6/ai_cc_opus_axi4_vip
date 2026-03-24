# VCS compile settings
VCS       = vcs
VLOGAN    = vlogan
VHDLAN    = vhdlan

# UVM
UVM_HOME  ?= $(VCS_HOME)/etc/uvm-1.2
UVM_ARGS   = +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv

# Source files (order matters)
SRC_FILES  = src/axi4_types.sv \
             src/axi4_if.sv \
             src/axi4_system_if.sv \
             src/axi4_pkg.sv \
             tb/axi4_tb_top.sv

# Compile flags
VCS_FLAGS  = -full64 -sverilog -timescale=1ns/1ps \
             +incdir+src \
             -ntb_opts uvm-1.2 \
             -debug_access+all \
             -LDFLAGS -Wl,--no-as-needed

# Simulation flags
SIM_FLAGS  = +UVM_TESTNAME=axi4_base_test \
             +UVM_VERBOSITY=UVM_MEDIUM

TOP        = axi4_tb_top
SIMV       = simv

.PHONY: all compile sim clean

all: compile

compile:
	$(VCS) $(VCS_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV)

sim: compile
	./$(SIMV) $(SIM_FLAGS)

clean:
	rm -rf $(SIMV) simv.daidir csrc ucli.key vc_hdrs.h DVEfiles \
	       *.log *.vpd *.fsdb AN.DB
