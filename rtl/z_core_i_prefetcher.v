module z_core_i_prefetcher (
    // Clock and Reset
    input clk;
    input rstn;

    // Control signals driven by the Control Unit


    // Axi Master Interface for Bursts Inputs (This will be connected directly to the AXI master)


    // Axi Master Interface for Bursts Outputs (This will be connected directly to the AXI master)

    

    // Output signals for driving the Instruction FIFO in the Control Unit

);

// Check control signals. Detect the necessity of a burst read and 
// generate the required burst read requests to the AXI master.

// When the prefetcher is receivig bursts, it will be storing
// the instructions in the Instruction FIFO. Generating the 
// necessary signals for the Control Unit to perform this task.


endmodule