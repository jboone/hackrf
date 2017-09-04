# Concepts borrowed from:
# https://github.com/duskwuff/Xilinx-ISE-Makefile/

###########################################################################
## Xilinx ISE Makefile
##
## To the extent possible under law, the author(s) have dedicated all copyright
## and related and neighboring rights to this software to the public domain
## worldwide. This software is distributed without any warranty.
###########################################################################

include project.cfg

###########################################################################
# Default values
###########################################################################

ifndef XILINX
    $(error XILINX must be defined)
endif

ifndef PROJECT
    $(error PROJECT must be defined)
endif

ifndef TARGET_PART
    $(error TARGET_PART must be defined)
endif

TOPLEVEL        ?= $(PROJECT)
CONSTRAINTS     ?= $(PROJECT).ucf
BITFILE         ?= build/$(TOPLEVEL).jed
IMPACT_CMDS		?= build/impact.cmd

COMMON_OPTS     ?= -intstyle ise
XST_OPTS        ?=
NGDBUILD_OPTS   ?=
MAP_OPTS        ?=
CPLDFIT_OPTS	?=
PAR_OPTS        ?=
TSIM_OPTS       ?=
NETGEN_OPS      ?= -rpw 100 -ar Structure
BITGEN_OPTS     ?=
TRACE_OPTS      ?=
FUSE_OPTS       ?= -incremental

PROGRAMMER      ?= none

IMPACT_OPTS     ?=

DJTG_EXE        ?= djtgcfg
DJTG_DEVICE     ?= DJTG_DEVICE-NOT-SET
DJTG_INDEX      ?= 0

XC3SPROG_EXE    ?= xc3sprog
XC3SPROG_CABLE  ?= none
XC3SPROG_OPTS   ?=


###########################################################################
# Internal variables, platform-specific definitions, and macros
###########################################################################

ifeq ($(OS),Windows_NT)
    XILINX := $(shell cygpath -m $(XILINX))
    CYG_XILINX := $(shell cygpath $(XILINX))
    EXE := .exe
    XILINX_PLATFORM ?= nt64
    PATH := $(PATH):$(CYG_XILINX)/bin/$(XILINX_PLATFORM)
else
    EXE :=
    XILINX_PLATFORM ?= lin64
    PATH := $(PATH):$(XILINX)/bin/$(XILINX_PLATFORM)
endif

TEST_NAMES = $(foreach file,$(VTEST) $(VHDTEST),$(basename $(file)))
TEST_EXES = $(foreach test,$(TEST_NAMES),build/isim_$(test)$(EXE))

RUN = @echo -ne "\n\n\e[1;33m======== $(1) ========\e[m\n\n"; \
	cd build && $(XILINX)/bin/$(XILINX_PLATFORM)/$(1)

# isim executables don't work without this
export XILINX


###########################################################################
# Default build
###########################################################################

default: $(BITFILE)

clean:
	rm -rf build

build/$(PROJECT).prj: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDSOURCE),echo "vhdl work \"../$(file)\"" >> $@;)

build/$(PROJECT)_sim.prj: build/$(PROJECT).prj
	@cp build/$(PROJECT).prj $@
	@$(foreach file,$(VTEST),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDTEST),echo "vhdl work \"../$(file)\"" >> $@;)
	@echo "verilog work $(XILINX)/verilog/src/glbl.v" >> $@

build/$(PROJECT).scr: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "$(XST_OPTS)" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p xbr" \
	    > build/$(PROJECT).scr

$(IMPACT_CMDS):
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "setMode -bs" >>$(IMPACT_CMDS)
	@echo "setCable -port xsvf -file \"default.xsvf\"" >>$(IMPACT_CMDS)
	@echo "addDevice -p 1 -file \"../$(BITFILE)\"" >>$(IMPACT_CMDS)
	@echo "program -p 1 -e -v" >>$(IMPACT_CMDS)
	@echo "quit" >>$(IMPACT_CMDS)

# xst -intstyle ise -ifn "/home/workspace/hackrf-cpld/full_duplex_if/top.xst" -ofn "/home/workspace/hackrf-cpld/full_duplex_if/top.syr" 
# ngdbuild -intstyle ise -dd _ngo -uc top.ucf -p xc2c64a-VQ100-7 top.ngc top.ngd  
# cpldfit -intstyle ise -p xc2c64a-7-VQ100 -ofmt vhdl -optimize density -htmlrpt -loc on -slew fast -init low -inputs 32 -pterms 28 -unused keeper -terminate keeper -iostd LVCMOS33 top.ngd 
# XSLTProcess top_build.xml
# tsim -intstyle ise top top.nga
# netgen -intstyle ise -rpw 100 -ar Structure -tm top -w -dir netgen/fit -ofmt vhdl -sim top.nga top_timesim.vhd
# taengine -intstyle ise -f top -w --format html1 -l top_html/tim/timing_report.htm
# hprep6 -s IEEE1149 -i top

$(BITFILE): project.cfg $(VSOURCE) $(CONSTRAINTS) build/$(PROJECT).prj build/$(PROJECT).scr
	@mkdir -p build
	$(call RUN,xst) $(COMMON_OPTS) \
	    -ifn $(PROJECT).scr \
	    -ofn $(PROJECT).syr
	$(call RUN,ngdbuild) $(COMMON_OPTS) $(NGDBUILD_OPTS) \
	    -p $(TARGET_PART_NGD) -uc ../$(CONSTRAINTS) \
	    $(PROJECT).ngc $(PROJECT).ngd
	$(call RUN,cpldfit) $(COMMON_OPTS) $(CPLDFIT_OPTS) \
	    -p $(TARGET_PART_BUILD) \
	    $(PROJECT).ngd
	$(call RUN,tsim) $(COMMON_OPTS) $(TSIM_OPTS) \
	    $(TOPLEVEL) $(PROJECT).nga
	$(call RUN,netgen) $(COMMON_OPTS) $(NETGEN_OPS) \
	    -tm $(TOPLEVEL) -w \
	    -dir netgen/fit -ofmt vhdl \
	    -sim $(PROJECT).nga \
	    top_timesim.vhd
	$(call RUN,taengine) $(COMMON_OPTS) -f $(TOPLEVEL) \
		-l $(TOPLEVEL)_timing.txt
	$(call RUN,taengine) $(COMMON_OPTS) -f $(TOPLEVEL) \
		-detail -l $(TOPLEVEL)_timing_detail.txt
	$(call RUN,hprep6) -s IEEE1149 -i $(PROJECT)
	@echo -ne "\e[1;32m======== OK ========\e[m\n"

###########################################################################
# Programming
###########################################################################

ifeq ($(PROGRAMMER), impact)
prog: $(BITFILE) $(IMPACT_CMDS)
	$(call RUN,impact) -batch ../$(IMPACT_CMDS) $(IMPACT_OPTS)
endif

ifeq ($(PROGRAMMER), digilent)
prog: $(BITFILE)
	$(DJTG_EXE) prog -d $(DJTG_DEVICE) -i $(DJTG_INDEX) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), xc3sprog)
prog: $(BITFILE)
	$(XC3SPROG_EXE) -c $(XC3SPROG_CABLE) $(XC3SPROG_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), none)
prog:
	$(error PROGRAMMER must be set to use 'make prog')
endif
