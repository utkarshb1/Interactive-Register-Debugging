DEBUG = NONE
VERSION = CYCLONE_V

DFLAGS = -fPIC -w -O3 -lowmem -release -boundscheck=off -g # -version=UVM_NO_DEPRECATED  -version=UVM_NO_WAIT_FOR_NBA

##########################################################################
#
# DUT Sources
#
##########################################################################

DUT_SRC_DIR=../rtl
_TARGETS_=	$(DUT_SRC_DIR)/apb_slave.v

##########################################################################
#
# Test Bench Sources
#
##########################################################################
_TOP_=tb_top
TB_SRC_DIR=../testbench
_TB_=		$(TB_SRC_DIR)/tb_top.v

all: apb.vvp apb.vpi

apb.vvp: $(_TARGETS_) $(_TB_)
	iverilog -f commands.f -I $(DUT_SRC_DIR) -I $(TB_SRC_DIR) -D WAVES -o $@ $^

clean:
	rm -f apb.vvp apb.vpi apb.o tr_db.log *.vcd

run: apb.vvp apb.vpi
	vvp -M. -mapb apb.vvp +UVM_VERBOSITY=DEBUG +UVM_TESTNAME=apb.linux_fifo_test # +UVM_OBJECTION_TRACE # 

# run: a.out
# 	./a.out

# clean:
# 	rm a.out
##########################################################################
#
# Misc Variables
#
##########################################################################

# a.out:
# 	iverilog -I $(DUT_SRC_DIR) -I $(TB_SRC_DIR) -D WAVES	\
# 	$(_TARGETS_) $(_TB_)

apb.vpi: $(TB_SRC_DIR)/apb.d
	ldmd2 $(DFLAGS) -shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-ldl $^
