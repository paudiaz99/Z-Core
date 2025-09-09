module reg_file_tb;

    // Initialize clk to 0
    reg clk = 0;

    
    reg [4:0] rd;
    reg [31:0] rd_in;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg reset;

    initial begin
        # 0 
        reset = 1'b1;
        rd = 5'b0;
        rs1 = 5'b0;
        rs2 = 5'b0;

        # 10 
        reset = 1'b0;
        rd = 5'd5;
        rd_in = 32'd15;

        // Write in x8
        # 10
        rd = 5'd8;
        rd_in = 32'd25;

        // Async Read from x8 and x5
        # 10 
        rs1 = 5'd5;
        rs2 = 5'd8;

        // Async Read from x8 and x5
        # 10 
        rs1 = 5'd8;
        rs2 = 5'd5;

        # 5 $stop;
    end

    always # 5 begin
        clk = ~clk;
    end

    wire [31:0] rs1_out;
    wire [31:0] rs2_out;

    z_core_reg_file reg_file (
        .clk
        ,.rd
        ,.rd_in
        ,.rs1
        ,.rs2
        ,.reset
        ,.rs1_out
        ,.rs2_out
    );

    initial begin
        $monitor("At time %t, rs1_out = %d, rs2_out = %d, clk = %b, rd = %d, rd_in = %d", $time, rs1_out, rs2_out, clk, rd, rd_in);
    end

endmodule