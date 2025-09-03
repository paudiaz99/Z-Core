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
    assign Iimm = {{21{inst[31]}},inst[30:20]};
    assign Simm = {{21{inst[31]}},inst[30:25],inst[11:7]};
    assign Bimm = {inst[7],inst[30:25],inst[11:8],1'b0};
    assign Uimm = {inst[31:12],{12{1'b0}}};
    assign Jimm = {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0};

endmodule