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
             -kdb \
             -LDFLAGS -Wl,--no-as-needed

# Simulation flags
TESTNAME  ?= narrow_test

SIM_FLAGS  = +UVM_TESTNAME=$(TESTNAME) \
             +UVM_VERBOSITY=UVM_MEDIUM \
             +FSDB_FILE=$(TESTNAME)

# Waveform dumping: make sim WAVE=1  (output: <TESTNAME>.fsdb)
WAVE      ?= 1
GUI 	  ?= 0
WAVE_FLAGS =
GUI_FLAGS =
ifeq ($(WAVE),1)
WAVE_FLAGS = +define+DUMP_WAVE
endif
ifeq ($(GUI),1)
GUI_FLAGS = -gui=verdi 
endif

TOP        = axi4_tb_top
SIMV       = simv
SIZE7_TEST        = axi4_fixed_len0_size7_test
BURST_INCR_TEST   = burst_incr_test
BURST_FIXED_TEST  = burst_fixed_test
BURST_WRAP_TEST   = burst_wrap_test
BURST_RANDOM_TEST = burst_random_test
BURST_SLICE_TEST  = burst_slice_test
UNALIGNED_ADDR_TEST = unaligned_addr_test

.PHONY: all compile sim wave clean sim_size7 sim_burst_incr sim_burst_fixed sim_burst_wrap sim_burst_random sim_burst_slice sim_unaligned_addr

all: compile

compile:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile.log

sim: compile
	./$(SIMV) $(SIM_FLAGS) -l $(TESTNAME).log $(GUI_FLAGS)
#-gui=verdi

# Run axi4_fixed_len0_size7_test with AI_AXI4_MAX_DATA_WIDTH=1024
sim_size7:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(SIZE7_TEST).log +define+AI_AXI4_MAX_DATA_WIDTH=1024 \
	    -l compile_$(SIZE7_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(SIZE7_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(SIZE7_TEST) \
	    -l $(SIZE7_TEST).log -gui=verdi

# Run burst_incr_test with default AI_AXI4_MAX_DATA_WIDTH=32
sim_burst_incr:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(BURST_INCR_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(BURST_INCR_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(BURST_INCR_TEST) \
	    -l $(BURST_INCR_TEST).log $(GUI_FLAGS)

# Run burst_fixed_test
sim_burst_fixed:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(BURST_FIXED_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(BURST_FIXED_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(BURST_FIXED_TEST) \
	    -l $(BURST_FIXED_TEST).log $(GUI_FLAGS)

# Run burst_wrap_test with default AI_AXI4_MAX_DATA_WIDTH=32
sim_burst_wrap:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(BURST_WRAP_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(BURST_WRAP_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(BURST_WRAP_TEST) \
	    -l $(BURST_WRAP_TEST).log $(GUI_FLAGS)

# Run burst_random_test
sim_burst_random:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(BURST_RANDOM_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(BURST_RANDOM_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(BURST_RANDOM_TEST) \
	    -l $(BURST_RANDOM_TEST).log $(GUI_FLAGS)

# Run burst_slice_test
sim_burst_slice:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(BURST_SLICE_TEST).log
	./$(SIMV) +UVM_TESTNAME=$(BURST_SLICE_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(BURST_SLICE_TEST) \
	    -l $(BURST_SLICE_TEST).log $(GUI_FLAGS)

# Run unaligned_addr_test with AI_AXI4_MAX_DATA_WIDTH=256
sim_unaligned_addr:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_$(UNALIGNED_ADDR_TEST).log +define+AI_AXI4_MAX_DATA_WIDTH=256
	./$(SIMV) +UVM_TESTNAME=$(UNALIGNED_ADDR_TEST) +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=$(UNALIGNED_ADDR_TEST) \
	    -l $(UNALIGNED_ADDR_TEST).log $(GUI_FLAGS)

sim_para_cfg1:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_para_cfg1_test.log +define+AI_AXI4_MAX_DATA_WIDTH=256 +define+AI_AXI4_MAX_ADDR_WIDTH=64 +define+AI_AXI4_MAX_ID_WIDTH=8
	./$(SIMV) +UVM_TESTNAME=para_cfg1_test +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=sim_para_cfg1 \
	    -l para_cfg1_test.log $(GUI_FLAGS)

sim_long_time:
	$(VCS) $(VCS_FLAGS) $(WAVE_FLAGS) $(UVM_ARGS) $(SRC_FILES) -top $(TOP) -o $(SIMV) \
	    -l compile_long_time_test.log
	./$(SIMV) +UVM_TESTNAME=long_time_test +UVM_VERBOSITY=UVM_MEDIUM \
	    +FSDB_FILE=long_time_test \
	    -l long_time_test.log $(GUI_FLAGS)

wave:
	verdi -sv +incdir+src $(SRC_FILES) -ssf $(TESTNAME).fsdb &

clean:
	rm -rf $(SIMV) simv.daidir csrc ucli.key vc_hdrs.h DVEfiles \
	       *.log *.vpd *.fsdb AN.DB verdiLog
