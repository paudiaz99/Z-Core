`include "rtl/z_core_branch_pred.v"

module z_core_branch_pred_tb;

reg clk;
reg rstn;
reg branch_taken;
reg is_branch;
reg [31:0] inst_addr;
reg [31:0] branch_target;

wire branch_taken_pred;
wire [31:0] branch_target_pred;

z_core_branch_pred branch_predictor(
    .clk(clk),
    .rstn(rstn),
    .branch_taken(branch_taken),
    .is_branch(is_branch),
    .inst_addr(inst_addr),
    .branch_target(branch_target),
    .branch_taken_pred(branch_taken_pred),
    .branch_target_pred(branch_target_pred)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("z_core_branch_pred_tb.vcd");
    $dumpvars(0, z_core_branch_pred_tb);

    rstn = 0;
    #10
    rstn = 1;
    is_branch = 1;
    branch_taken = 1;
    #10
    
    #100

    $finish;
end

endmodule