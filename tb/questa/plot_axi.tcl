set axi_chans {AR R AW W B}
array set axi_cols {AR "aquamarine"
                    R "cyan"
                    AW "thistle"
                    W "magenta"
                    B "violet"
                    }

# medium aquamarine
set chan_AR {\
    arvalid\
    arready\
    araddr\
    arprot\
}

# aquamarine
set chan_R {\
    rvalid\
    rready\
    rdata\
    rresp\
}

# medium orchid 
set chan_AW {\
    awvalid\
    awready\
    awaddr\
    awprot\
}

# orchid
set chan_W {\
    wvalid\
    wready\
    wdata\
    wstrb\
}

# violet
set chan_B {\
    bvalid\
    bready\
    bresp\
}

proc add_axi_waveforms {prefix chan chan_signals color} {
    foreach sig ${chan_signals} {
        add wave -color ${color} -position end -group "${chan}" "${prefix}${sig}"
    }
}