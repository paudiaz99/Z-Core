module dec_tb;

    // Input instruction
    reg [31:0] inst;
    initial begin
        # 0 inst =  32'b00000000001000001000100000100011;
        # 10 inst = 32'b00100000000100101000000000100011;
        # 20 $stop;
    end

    wire [6:0] op;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [11:0] Iimm;
    wire [11:0] Simm;
    wire [19:0] Uimm;
    wire [11:0] Bimm;
    wire [19:0] Jimm;
    wire [2:0] funct3;
    wire [6:0] funct7;

    // Instantiate the decoder module
    z_core_decoder dec (
        .inst, // Corrected: Connect testbench signal 'inst' to decoder's 'inst' port
        .op,
        .rs1,
        .rs2,
        .rd,
        .Iimm,
        .Simm,
        .Uimm,
        .Bimm,
        .Jimm,
        .funct3,
        .funct7
    );

    // Monitor the outputs
    initial begin
        $monitor("At time %t, op=%d, rd=%d, rs1=%d, rs2=%d", $time, op, rd, rs1, rs2);
        // $monitor("At time %t, Iimm=%d, Simm=%d, Uimm=%d, Bimm=%d, Jimm=%d", $time, Iimm, Simm, Uimm, Bimm, Jimm);
    end

endmodule


