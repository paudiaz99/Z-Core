# Choose simulator (questa/dsim/iverilog)
SIM 							?= questa

# Default testbench file
TB_FILE      			?= z_core_control_u_tb.sv

# Supported testbench files
TB_FILES_ALL := axil_gpio_tb.v \
								tb_mult_unit.v \
								z_core_alu_ctrl_tb.v \
								z_core_alu_tb.v \
								z_core_control_u_tb.sv \
								z_core_decoder_tb.v \
								z_core_div_unit_tb.v \
								z_core_reg_file_tb.v \
								z_core_riscof_tb.sv

# Goals
.PHONY: compile run clean-all clean-questa clean-dsim clean-waves clean-logs lint
.DEFAULT_GOAL 		:= help

###############################################################################
# Variables: Verilog
###############################################################################

# DFLAGS       			:= +define+USE_TREE_MULTIPLIER

# RTL source files for iverilog (needs to be expanded immediately)
RTL_FILES 				:= $(addprefix ../rtl/, $(shell cat ../rtl/flist.vc))

TB_TOP            := $(basename $(TB_FILE))
TB_TOP_OPT	   		:= $(TB_TOP)_opt

COMPILE_LOG_DIR 	:= logs/compile.$(SIM)
RUN_LOG_DIR     	:= logs/tests.$(SIM)/$(TB_TOP)

################################################################################
# Default target: help
################################################################################
help:
	@echo
	@echo "Usage: make -f ../tb/Makefile target [options]"
	@echo
	@echo "targets:"
	@echo "	help              : Shows this help information"
	@echo "	compile           : Compile the testbench"
	@echo "	run               : Run simulation for a given test"
	@echo "	all               : Compile and execute all available tests"
	@echo "	clean-all         : Clean all generated files (logs, waves, work dirs)"
	@echo
	@echo "Options:"
	@echo "	TB_FILE=<tb-file>	: Test-bench to run, e.g.: TB_FILE=z_core_alu_tb.v"
	@echo "					Supported tests: ${TB_FILES_ALL}"
	@echo "					Default: z_core_control_u_tb.sv"
	@echo "	SIM=<simulator>		: Choose simulator (questa or dsim) for compiling the testbench and running the tests"
	@echo "					Default: questa"
	@echo "	debug=1			: Enable debug mode (waveform generation and GUI mode)"
	@echo

###############################################################################
# Siemens Questasim compilation & run commands
###############################################################################

ifeq ($(SIM),questa)
  ifdef debug
    DEBUG_VOPT := -debugdb +acc
    RUN_OPTS := -debugdb +acc -gui -do "source ../tb/questa/sim.tcl"
  else
    RUN_OPTS := -batch -do "$(FSDB_RUN) run -a; quit -f"
  endif

COMPILE_OPTS := -lint=full $(DFLAGS) -timescale 1ns/1ns

COMPILE_CMD := vlog \
               $(COMPILE_OPTS) \
               -F ../rtl/flist.vc \
               -l $(COMPILE_LOG_DIR)/questa_compile.log;
COMPILE_CMD += vlog \
               $(COMPILE_OPTS) \
               ../tb/$(TB_FILE) \
               -l $(COMPILE_LOG_DIR)/questa_compile_tb.log;
COMPILE_CMD += vopt \
               $(DEBUG_VOPT) \
               $(TB_TOP) \
               -o $(TB_TOP_OPT) \
               -l $(COMPILE_LOG_DIR)/questa_opt.log;
RUN_CMD := vsim \
           $(RUN_OPTS) \
           $(DEBUG_VSIM) \
           $(TB_TOP_OPT) \
           -l $(RUN_LOG_DIR)/questa_sim.log;
endif

###############################################################################
# Altair DSim compilation & run commands
###############################################################################

ifeq ($(SIM),dsim)
  ifdef debug
    DEBUG_OPT := +acc
    DEBUG_RUN_OPTS := +acc -waves $(TB_TOP).vcd
  endif

COMPILE_OPTS := -timescale 1ns/1ns $(DFLAGS) -genimage image

COMPILE_CMD := dsim \
               $(DEBUG_OPT) \
               $(COMPILE_OPTS) \
               -F ../rtl/flist.vc \
               ../tb/$(TB_FILE) \
               -l $(COMPILE_LOG_DIR)/dsim_compile.log;

RUN_CMD := dsim \
           -image image \
           $(DEBUG_OPT) \
           $(DEBUG_RUN_OPTS) \
           -l $(RUN_LOG_DIR)/dsim_sim.log;
endif

###############################################################################
# Icarus Verilog compilation & run commands
###############################################################################

ifeq ($(SIM),iverilog)
COMPILE_CMD := iverilog \
								-g2012 \
								$(subst +define+,-D,$(DFLAGS)) \
								-o $(TB_TOP).vvp \
								$(RTL_FILES) \
								../tb/$(TB_FILE) \
								> $(COMPILE_LOG_DIR)/iverilog_compile.log 2>&1;

RUN_CMD := vvp \
						-l $(RUN_LOG_DIR)/iverilog_sim.log \
						$(TB_TOP).vvp;
endif

###############################################################################
# Compilation rule
###############################################################################

compile:
	@echo "** Clearing previous logs **"
	@rm -rf $(COMPILE_LOG_DIR)
	@mkdir -p $(COMPILE_LOG_DIR)
	@echo
	@echo "** Compiling testbench **"
	$(COMPILE_CMD)

###############################################################################
# Run rule
###############################################################################

run: compile
	@mkdir -p $(RUN_LOG_DIR)
	@echo
	@echo "** Running $(TB_TOP) **"
	$(RUN_CMD)

###############################################################################
# Make all rule
###############################################################################
all: compile
	@$(foreach test, ${TB_FILES_ALL}, $(MAKE) -f ../tb/Makefile run TB_FILE=$(test);)

###############################################################################
# Lint rule
###############################################################################

lint:
	slang --top z_core_top -Weverything -F ../rtl/flist.vc

###############################################################################
# Clean rule
###############################################################################

clean-all: clean-dsim clean-questa clean-iverilog

clean-questa: clean-waves clean-logs
	rm -rf ./work vsim*

clean-dsim: clean-waves clean-logs
	rm -rf dsim_work dsim.env metrics.db

clean-iverilog: clean-logs
	rm -rf *.vvp

clean-waves:
	rm -rf *.vcd

clean-logs:
	rm -rf logs