# Questa wave configuration script

# AXI channels and their colors
source ../tb/questa/plot_axi.tcl

# log all signals
log -r /*

set sim_base sim:/z_core_control_u_tb

# testbench signals
add wave -divider "TB Signals"
add wave ${sim_base}/clk
add wave ${sim_base}/rstn
add wave ${sim_base}/instruction_count

# RSEMM AXI slave
# interface to provide RSE and Security Control Processor (SCP) access to SI-Salus components.
add wave -divider "AXI-L Master"
foreach ch ${axi_chans} {
    add_axi_waveforms ${sim_base}/s_axil_ "M0_${ch}" [set chan_${ch}] $axi_cols($ch)
}

add wave -divider "Core Signals"
add wave ${sim_base}/uut/PC 

##########################################################
## waveform configuration
##########################################################
configure wave -namecolwidth 350
configure wave -valuecolwidth 50
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 6
configure wave -childrowmargin 4
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

update

run -all

wave zoom full

add schematic  \
  sim:/z_core_control_u_tb/uut/PC