module z_core_decoder (
    input [31:0] inst,
    output [6:0] op,
    output [4:0] rs1,
    output [4:0] rs2,
    output [4:0] rd,
    output [31:0] Iimm,
    output [31:0] Simm,
    output [31:0] Uimm,
    output [31:0] Bimm,
    output [31:0] Jimm,
    output [2:0] funct3,
    output [6:0] funct7
);

    // Decode Operation
    assign op = inst[6:0];

    // Decode Registers
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];

    // Decode Funct
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    // Decode Immediates
    // I-type: imm[11:0] = inst[31:20], sign-extended
    assign Iimm = {{21{inst[31]}}, inst[30:20]};
    // S-type: imm[11:5|4:0] = inst[31:25|11:7], sign-extended
    assign Simm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    // B-type: imm[12|10:5|4:1|11] = inst[31|30:25|11:8|7], sign-extended
    assign Bimm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    // U-type: imm[31:12] = inst[31:12], lower 12 bits zero
    assign Uimm = {inst[31:12], {12{1'b0}}};
    // J-type: imm[20|10:1|11|19:12] = inst[31|30:21|20|19:12], sign-extended
    assign Jimm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};

endmodule