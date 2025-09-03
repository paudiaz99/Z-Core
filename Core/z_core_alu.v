
module z_core_alu (
    input clk,
    input [31:0] alu_in1,
    input [31:0] alu_in2,
    input [6:0] alu_op,
    input [2:0] alu_funct3,
    input [6:0] alu_funct7,
    output [31:0] alu_out,
    output alu_branch
);

reg [31:0] alu_out_r;
reg alu_branch_r;

always @(alu_op or alu_in1 or alu_in2) begin
    // TODO
end

assign alu_out = alu_out_r;
assign alu_branch = alu_branch_r;

endmodule