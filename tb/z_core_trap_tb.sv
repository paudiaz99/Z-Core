/*

Copyright (c) 2025 Pau Diaz Cuesta

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

// **************************************************
//          Z-Core Trap-Focused Verification TB
//  Exceptions + Interrupts + CSR trap semantics
// **************************************************

module z_core_trap_tb;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);
    parameter INST_CACHE_DEPTH = 4096;
    parameter DATA_CACHE_DEPTH = 8192;

    // Only memory is required for trap-focused tests.
    localparam S_COUNT = 1;
    localparam M_COUNT = 1;
    localparam M_REGIONS = 1;

    localparam [M_COUNT*ADDR_WIDTH-1:0] M_BASE_ADDR = {
        32'h0000_0000
    };

    localparam [M_COUNT*32-1:0] M_ADDR_WIDTH_CONF = {
        32'd16 // 64KB memory window in this TB
    };

    // Cause codes
    localparam [31:0] CAUSE_EXC_ILLEGAL = 32'd2;
    localparam [31:0] CAUSE_EXC_BREAK   = 32'd3;
    localparam [31:0] CAUSE_EXC_ECALL_M = 32'd11;
    localparam [31:0] CAUSE_IRQ_MSI     = 32'h8000_0003;
    localparam [31:0] CAUSE_IRQ_MTI     = 32'h8000_0007;
    localparam [31:0] CAUSE_IRQ_MEI     = 32'h8000_000B;

    // Simple instruction constants
    localparam [31:0] INSN_NOP    = 32'h0000_0013;
    localparam [31:0] INSN_ECALL  = 32'h0000_0073;
    localparam [31:0] INSN_EBREAK = 32'h0010_0073;
    localparam [31:0] INSN_MRET   = 32'h3020_0073;
    localparam [31:0] INSN_ILLEGAL = 32'hFFFF_FFFF;

    // Clock / reset / interrupt pins
    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg meip = 1'b0;
    reg mtip = 1'b0;
    reg msip = 1'b0;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Interconnect wires
    wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_awaddr;
    wire [S_COUNT*3-1:0]           s_axil_awprot;
    wire [S_COUNT-1:0]             s_axil_awvalid;
    wire [S_COUNT-1:0]             s_axil_awready;
    wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_wdata;
    wire [S_COUNT*STRB_WIDTH-1:0]  s_axil_wstrb;
    wire [S_COUNT-1:0]             s_axil_wvalid;
    wire [S_COUNT-1:0]             s_axil_wready;
    wire [S_COUNT*2-1:0]           s_axil_bresp;
    wire [S_COUNT-1:0]             s_axil_bvalid;
    wire [S_COUNT-1:0]             s_axil_bready;
    wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_araddr;
    wire [S_COUNT*3-1:0]           s_axil_arprot;
    wire [S_COUNT-1:0]             s_axil_arvalid;
    wire [S_COUNT-1:0]             s_axil_arready;
    wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_rdata;
    wire [S_COUNT*2-1:0]           s_axil_rresp;
    wire [S_COUNT-1:0]             s_axil_rvalid;
    wire [S_COUNT-1:0]             s_axil_rready;

    wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_awaddr;
    wire [M_COUNT*3-1:0]           m_axil_awprot;
    wire [M_COUNT-1:0]             m_axil_awvalid;
    wire [M_COUNT-1:0]             m_axil_awready;
    wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_wdata;
    wire [M_COUNT*STRB_WIDTH-1:0]  m_axil_wstrb;
    wire [M_COUNT-1:0]             m_axil_wvalid;
    wire [M_COUNT-1:0]             m_axil_wready;
    wire [M_COUNT*2-1:0]           m_axil_bresp;
    wire [M_COUNT-1:0]             m_axil_bvalid;
    wire [M_COUNT-1:0]             m_axil_bready;
    wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_araddr;
    wire [M_COUNT*3-1:0]           m_axil_arprot;
    wire [M_COUNT-1:0]             m_axil_arvalid;
    wire [M_COUNT-1:0]             m_axil_arready;
    wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_rdata;
    wire [M_COUNT*2-1:0]           m_axil_rresp;
    wire [M_COUNT-1:0]             m_axil_rvalid;
    wire [M_COUNT-1:0]             m_axil_rready;

    // ==========================================
    // Utility encoders
    // ==========================================

    function automatic [31:0] enc_i;
        input [6:0] opcode;
        input [2:0] funct3;
        input [4:0] rd;
        input [4:0] rs1;
        input integer imm;
        reg signed [11:0] simm;
        begin
            simm = imm;
            enc_i = {simm[11:0], rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic [31:0] enc_s;
        input [6:0] opcode;
        input [2:0] funct3;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer imm;
        reg signed [11:0] simm;
        begin
            simm = imm;
            enc_s = {simm[11:5], rs2, rs1, funct3, simm[4:0], opcode};
        end
    endfunction

    function automatic [31:0] enc_b;
        input [6:0] opcode;
        input [2:0] funct3;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer imm;
        reg signed [12:0] simm;
        begin
            simm = imm;
            enc_b = {simm[12], simm[10:5], rs2, rs1, funct3, simm[4:1], simm[11], opcode};
        end
    endfunction

    function automatic [31:0] enc_csr_reg;
        input [2:0] funct3;
        input [4:0] rd;
        input [4:0] rs1;
        input [11:0] csr_addr;
        begin
            enc_csr_reg = {csr_addr, rs1, funct3, rd, 7'h73};
        end
    endfunction

    function automatic [31:0] enc_csr_imm;
        input [2:0] funct3;
        input [4:0] rd;
        input [4:0] zimm;
        input [11:0] csr_addr;
        begin
            enc_csr_imm = {csr_addr, zimm, funct3, rd, 7'h73};
        end
    endfunction

    function automatic [31:0] read_reg;
        input [4:0] reg_num;
        begin
            case (reg_num)
                5'd0:  read_reg = 32'h0000_0000;
                5'd1:  read_reg = uut.reg_file.reg_r1_q;
                5'd2:  read_reg = uut.reg_file.reg_r2_q;
                5'd3:  read_reg = uut.reg_file.reg_r3_q;
                5'd4:  read_reg = uut.reg_file.reg_r4_q;
                5'd5:  read_reg = uut.reg_file.reg_r5_q;
                5'd6:  read_reg = uut.reg_file.reg_r6_q;
                5'd7:  read_reg = uut.reg_file.reg_r7_q;
                5'd8:  read_reg = uut.reg_file.reg_r8_q;
                5'd9:  read_reg = uut.reg_file.reg_r9_q;
                5'd10: read_reg = uut.reg_file.reg_r10_q;
                5'd11: read_reg = uut.reg_file.reg_r11_q;
                5'd12: read_reg = uut.reg_file.reg_r12_q;
                5'd13: read_reg = uut.reg_file.reg_r13_q;
                5'd14: read_reg = uut.reg_file.reg_r14_q;
                5'd15: read_reg = uut.reg_file.reg_r15_q;
                5'd16: read_reg = uut.reg_file.reg_r16_q;
                5'd17: read_reg = uut.reg_file.reg_r17_q;
                5'd18: read_reg = uut.reg_file.reg_r18_q;
                5'd19: read_reg = uut.reg_file.reg_r19_q;
                5'd20: read_reg = uut.reg_file.reg_r20_q;
                5'd21: read_reg = uut.reg_file.reg_r21_q;
                5'd22: read_reg = uut.reg_file.reg_r22_q;
                5'd23: read_reg = uut.reg_file.reg_r23_q;
                5'd24: read_reg = uut.reg_file.reg_r24_q;
                5'd25: read_reg = uut.reg_file.reg_r25_q;
                5'd26: read_reg = uut.reg_file.reg_r26_q;
                5'd27: read_reg = uut.reg_file.reg_r27_q;
                5'd28: read_reg = uut.reg_file.reg_r28_q;
                5'd29: read_reg = uut.reg_file.reg_r29_q;
                5'd30: read_reg = uut.reg_file.reg_r30_q;
                5'd31: read_reg = uut.reg_file.reg_r31_q;
                default: read_reg = 32'hDEAD_BEEF;
            endcase
        end
    endfunction

    // ==========================================
    // DUT + fabric
    // ==========================================

    axil_interconnect #(
        .S_COUNT(S_COUNT),
        .M_COUNT(M_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .M_REGIONS(M_REGIONS),
        .M_BASE_ADDR(M_BASE_ADDR),
        .M_ADDR_WIDTH(M_ADDR_WIDTH_CONF)
    ) u_interconnect (
        .clk(clk),
        .rst(~rstn),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .m_axil_awaddr(m_axil_awaddr),
        .m_axil_awprot(m_axil_awprot),
        .m_axil_awvalid(m_axil_awvalid),
        .m_axil_awready(m_axil_awready),
        .m_axil_wdata(m_axil_wdata),
        .m_axil_wstrb(m_axil_wstrb),
        .m_axil_wvalid(m_axil_wvalid),
        .m_axil_wready(m_axil_wready),
        .m_axil_bresp(m_axil_bresp),
        .m_axil_bvalid(m_axil_bvalid),
        .m_axil_bready(m_axil_bready),
        .m_axil_araddr(m_axil_araddr),
        .m_axil_arprot(m_axil_arprot),
        .m_axil_arvalid(m_axil_arvalid),
        .m_axil_arready(m_axil_arready),
        .m_axil_rdata(m_axil_rdata),
        .m_axil_rresp(m_axil_rresp),
        .m_axil_rvalid(m_axil_rvalid),
        .m_axil_rready(m_axil_rready)
    );

    z_core_control_u #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .INST_CACHE_DEPTH(INST_CACHE_DEPTH),
        .DATA_CACHE_DEPTH(DATA_CACHE_DEPTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
        .m_axil_awaddr(s_axil_awaddr),
        .m_axil_awprot(s_axil_awprot),
        .m_axil_awvalid(s_axil_awvalid),
        .m_axil_awready(s_axil_awready),
        .m_axil_wdata(s_axil_wdata),
        .m_axil_wstrb(s_axil_wstrb),
        .m_axil_wvalid(s_axil_wvalid),
        .m_axil_wready(s_axil_wready),
        .m_axil_bresp(s_axil_bresp),
        .m_axil_bvalid(s_axil_bvalid),
        .m_axil_bready(s_axil_bready),
        .m_axil_araddr(s_axil_araddr),
        .m_axil_arprot(s_axil_arprot),
        .m_axil_arvalid(s_axil_arvalid),
        .m_axil_arready(s_axil_arready),
        .m_axil_rdata(s_axil_rdata),
        .m_axil_rresp(s_axil_rresp),
        .m_axil_rvalid(s_axil_rvalid),
        .m_axil_rready(s_axil_rready),
        .meip(meip),
        .mtip(mtip),
        .msip(msip)
    );

    axil_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(16),
        .STRB_WIDTH(STRB_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_axil_ram (
        .clk(clk),
        .rstn(rstn),
        .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: 16]),
        .s_axil_awprot(m_axil_awprot[0*3 +: 3]),
        .s_axil_awvalid(m_axil_awvalid[0]),
        .s_axil_awready(m_axil_awready[0]),
        .s_axil_wdata(m_axil_wdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_wstrb(m_axil_wstrb[0*STRB_WIDTH +: STRB_WIDTH]),
        .s_axil_wvalid(m_axil_wvalid[0]),
        .s_axil_wready(m_axil_wready[0]),
        .s_axil_bresp(m_axil_bresp[0*2 +: 2]),
        .s_axil_bvalid(m_axil_bvalid[0]),
        .s_axil_bready(m_axil_bready[0]),
        .s_axil_araddr(m_axil_araddr[0*ADDR_WIDTH +: 16]),
        .s_axil_arprot(m_axil_arprot[0*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[0]),
        .s_axil_arready(m_axil_arready[0]),
        .s_axil_rdata(m_axil_rdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[0*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[0]),
        .s_axil_rready(m_axil_rready[0])
    );

    // 100MHz
    always #5 clk = ~clk;

    // Safety timeout
    initial begin
        #2_000_000;
        $display("\n[ERROR] Simulation timeout in z_core_trap_tb");
        $finish;
    end

    // ==========================================
    // Generic tasks
    // ==========================================

    task wait_cycles;
        input integer n;
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    task reset_cpu;
        begin
            meip = 1'b0;
            mtip = 1'b0;
            msip = 1'b0;
            rstn = 1'b0;
            wait_cycles(12);
            rstn = 1'b1;
            wait_cycles(8);
        end
    endtask

    task clear_ram;
        integer i;
        begin
            for (i = 0; i < 2048; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h0000_0000;
            end
        end
    endtask

    task put_insn;
        input [31:0] addr;
        input [31:0] insn;
        begin
            u_axil_ram.mem[addr >> 2] = insn;
        end
    endtask

    task check_mem;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] name;
        reg [31:0] actual;
        reg [16:0] expected_tag;
        reg [12:0] cache_index;
        reg        in_cache;
        begin
            test_count = test_count + 1;
            in_cache     = 1'b0;
            expected_tag = addr[31:15];
            cache_index  = addr[14:2];

            // Check data cache first (2-way, DATA_CACHE_DEPTH=8192)
            if (uut.data_cache.valid_bits[0][cache_index] &&
                uut.data_cache.tags[0][cache_index] === expected_tag) begin
                actual   = uut.data_cache.data[0][cache_index];
                in_cache = 1'b1;
            end else if (uut.data_cache.valid_bits[1][cache_index] &&
                         uut.data_cache.tags[1][cache_index] === expected_tag) begin
                actual   = uut.data_cache.data[1][cache_index];
                in_cache = 1'b1;
            end else begin
                actual = u_axil_ram.mem[addr >> 2];
            end

            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: %s[0x%0h] = 0x%08h", name, in_cache ? "cache" : "  mem", addr, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: %s[0x%0h] = 0x%08h (expected 0x%08h)", name, in_cache ? "cache" : "  mem", addr, actual, expected);
            end
        end
    endtask

    task check_reg;
        input [4:0] reg_num;
        input [31:0] expected;
        input [255:0] name;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;
            actual = read_reg(reg_num);
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: x%0d = 0x%08h", name, reg_num, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: x%0d = 0x%08h (expected 0x%08h)", name, reg_num, actual, expected);
            end
        end
    endtask

    task pulse_irq;
        input [1:0] irq_sel; // 0=MEI, 1=MTI, 2=MSI
        input integer ncycles;
        begin
            case (irq_sel)
                2'd0: meip = 1'b1;
                2'd1: mtip = 1'b1;
                default: msip = 1'b1;
            endcase
            wait_cycles(ncycles);
            meip = 1'b0;
            mtip = 1'b0;
            msip = 1'b0;
        end
    endtask

    // ==========================================
    // Program generators
    // ==========================================

    task load_common_handler;
        begin
            // 0x80: csrr x10, mcause
            put_insn(32'h080, enc_csr_reg(3'b010, 5'd10, 5'd0, 12'h342));
            // 0x84: csrr x11, mepc
            put_insn(32'h084, enc_csr_reg(3'b010, 5'd11, 5'd0, 12'h341));
            // 0x88: csrr x12, mtval
            put_insn(32'h088, enc_csr_reg(3'b010, 5'd12, 5'd0, 12'h343));
            // 0x8C: csrr x13, mstatus
            put_insn(32'h08C, enc_csr_reg(3'b010, 5'd13, 5'd0, 12'h300));
            // 0x90: blt x10, x0, +12 (interrupt path: skip mepc advance)
            put_insn(32'h090, enc_b(7'h63, 3'b100, 5'd10, 5'd0, 12));
            // 0x94: addi x11, x11, 4
            put_insn(32'h094, enc_i(7'h13, 3'b000, 5'd11, 5'd11, 4));
            // 0x98: csrw mepc, x11
            put_insn(32'h098, enc_csr_reg(3'b001, 5'd0, 5'd11, 12'h341));
            // 0x9C: sw x10, 0(x31)
            put_insn(32'h09C, enc_s(7'h23, 3'b010, 5'd31, 5'd10, 0));
            // 0xA0: sw x11, 4(x31)
            put_insn(32'h0A0, enc_s(7'h23, 3'b010, 5'd31, 5'd11, 4));
            // 0xA4: sw x12, 8(x31)
            put_insn(32'h0A4, enc_s(7'h23, 3'b010, 5'd31, 5'd12, 8));
            // 0xA8: sw x13, 12(x31)
            put_insn(32'h0A8, enc_s(7'h23, 3'b010, 5'd31, 5'd13, 12));
            // 0xAC: addi x31, x31, 16
            put_insn(32'h0AC, enc_i(7'h13, 3'b000, 5'd31, 5'd31, 16));
            // 0xB0: addi x30, x30, 1
            put_insn(32'h0B0, enc_i(7'h13, 3'b000, 5'd30, 5'd30, 1));
            // 0xB4: addi x29, x0, 1    — set "handled" flag (used by timer IRQ test spin loop)
            put_insn(32'h0B4, enc_i(7'h13, 3'b000, 5'd29, 5'd0, 1));
            // 0xB8: mret
            put_insn(32'h0B8, INSN_MRET);
        end
    endtask

    task load_exception_program;
        begin
            clear_ram();
            load_common_handler();

            put_insn(32'h000, enc_i(7'h13, 3'b000, 5'd31, 5'd0, 32'h200)); // x31=log base
            put_insn(32'h004, enc_i(7'h13, 3'b000, 5'd20, 5'd0, 0));       // x20=0
            put_insn(32'h008, enc_i(7'h13, 3'b000, 5'd1,  5'd0, 32'h080)); // x1=mtvec
            put_insn(32'h00C, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h305));   // csrw mtvec, x1
            put_insn(32'h010, INSN_ECALL);                                  // trap 1
            put_insn(32'h014, enc_i(7'h13, 3'b000, 5'd20, 5'd20, 1));      // x20++
            put_insn(32'h018, INSN_EBREAK);                                 // trap 2
            put_insn(32'h01C, enc_i(7'h13, 3'b000, 5'd20, 5'd20, 1));      // x20++
            put_insn(32'h020, INSN_ILLEGAL);                                // trap 3
            put_insn(32'h024, enc_i(7'h13, 3'b000, 5'd20, 5'd20, 1));      // x20++
            put_insn(32'h028, enc_s(7'h23, 3'b010, 5'd0, 5'd20, 32'h240)); // store post-MRET count
            put_insn(32'h02C, enc_b(7'h63, 3'b000, 5'd0, 5'd0, 0));        // beq x0,x0,0
        end
    endtask

    task load_irq_spin_program;
        input [31:0] log_base;
        input [31:0] mie_mask;
        begin
            clear_ram();
            load_common_handler();

            put_insn(32'h000, enc_i(7'h13, 3'b000, 5'd31, 5'd0, log_base)); // x31=log base
            put_insn(32'h004, enc_i(7'h13, 3'b000, 5'd30, 5'd0, 0));         // x30=0
            put_insn(32'h008, enc_i(7'h13, 3'b000, 5'd1,  5'd0, 32'h080));   // x1=mtvec
            put_insn(32'h00C, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h305));     // csrw mtvec, x1
            put_insn(32'h010, enc_i(7'h13, 3'b000, 5'd1,  5'd0, mie_mask));  // x1=mie mask
            put_insn(32'h014, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h304));     // csrw mie, x1
            put_insn(32'h018, enc_csr_imm(3'b110, 5'd0, 5'd8, 12'h300));     // csrsi mstatus, 8
            put_insn(32'h01C, enc_i(7'h13, 3'b000, 5'd5,  5'd5, 1));         // addi x5, x5, 1
            put_insn(32'h020, enc_b(7'h63, 3'b000, 5'd0, 5'd0, -4));         // beq x0, x0, -4
        end
    endtask

    task load_mask_matrix_program;
        input [31:0] mie_mask;
        input integer enable_global;
        begin
            clear_ram();
            load_common_handler();

            put_insn(32'h000, enc_i(7'h13, 3'b000, 5'd31, 5'd0, 32'h300)); // x31=log base
            put_insn(32'h004, enc_i(7'h13, 3'b000, 5'd30, 5'd0, 0));       // x30=0
            put_insn(32'h008, enc_i(7'h13, 3'b000, 5'd1,  5'd0, 32'h080)); // x1=mtvec
            put_insn(32'h00C, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h305));   // csrw mtvec, x1
            put_insn(32'h010, enc_i(7'h13, 3'b000, 5'd1,  5'd0, mie_mask));// x1=mie
            put_insn(32'h014, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h304));   // csrw mie, x1
            if (enable_global != 0) begin
                put_insn(32'h018, enc_csr_imm(3'b110, 5'd0, 5'd8, 12'h300)); // csrsi mstatus, 8
            end else begin
                put_insn(32'h018, INSN_NOP);
            end
            put_insn(32'h01C, enc_i(7'h13, 3'b000, 5'd5, 5'd0, 40));         // x5=40
            put_insn(32'h020, enc_i(7'h13, 3'b000, 5'd5, 5'd5, -1));         // loop: x5--
            put_insn(32'h024, enc_b(7'h63, 3'b001, 5'd5, 5'd0, -4));         // bne x5,x0,loop
            put_insn(32'h028, enc_b(7'h63, 3'b000, 5'd0, 5'd0, 0));          // beq x0,x0,0
        end
    endtask

    task load_timer_irq_program;
        input [31:0] log_base;
        begin
            clear_ram();
            load_common_handler();

            // Main program:
            //   Setup mtvec, enable MTIE + MIE, then spin.
            //   Handler sets x29 = 1 as a "handled" flag.
            //   After MRET, spin loop checks x29 and exits.
            put_insn(32'h000, enc_i(7'h13, 3'b000, 5'd31, 5'd0, log_base)); // x31 = log base
            put_insn(32'h004, enc_i(7'h13, 3'b000, 5'd30, 5'd0, 0));        // x30 = 0 (trap counter)
            put_insn(32'h008, enc_i(7'h13, 3'b000, 5'd29, 5'd0, 0));        // x29 = 0 (handled flag)
            put_insn(32'h00C, enc_i(7'h13, 3'b000, 5'd1,  5'd0, 32'h080)); // x1 = mtvec
            put_insn(32'h010, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h305));    // csrw mtvec, x1
            put_insn(32'h014, enc_i(7'h13, 3'b000, 5'd1,  5'd0, 32'h080)); // x1 = 0x80 (MTIE bit)
            put_insn(32'h018, enc_csr_reg(3'b001, 5'd0, 5'd1, 12'h304));    // csrw mie, x1
            put_insn(32'h01C, enc_csr_imm(3'b110, 5'd0, 5'd8, 12'h300));    // csrsi mstatus, 8
            // 0x20: spin loop — break out when x29 != 0 (handler sets it)
            put_insn(32'h020, enc_b(7'h63, 3'b001, 5'd29, 5'd0, 8));        // bne x29, x0, +8
            put_insn(32'h024, enc_b(7'h63, 3'b000, 5'd0, 5'd0, -4));        // beq x0, x0, -4
            // 0x28: landed here after handler set x29=1
            put_insn(32'h028, enc_b(7'h63, 3'b000, 5'd0, 5'd0, 0));         // done: infinite loop
        end
    endtask

    // ==========================================
    // Test sequence
    // ==========================================

    initial begin
        $display("\n==============================================");
        $display("  Z-Core Trap Verification Testbench");
        $display("  Phases: directed, matrix, stress, regression");
        $display("==============================================\n");

        // ---------------------------
        // Phase 1: Directed traps
        // ---------------------------
        $display("[Phase 1] Directed exceptions");
        load_exception_program();
        reset_cpu();
        // Exception flow performs 3 trap entries/exits through AXI-backed fetch;
        // keep this window generous to avoid false negatives from testbench timing.
        wait_cycles(1800);
        check_mem(32'h200, CAUSE_EXC_ECALL_M, "ECALL mcause");
        check_mem(32'h204, 32'h0000_0014, "ECALL mepc+4");
        check_mem(32'h210, CAUSE_EXC_BREAK, "EBREAK mcause");
        check_mem(32'h214, 32'h0000_001C, "EBREAK mepc+4");
        check_mem(32'h220, CAUSE_EXC_ILLEGAL, "Illegal mcause");
        check_mem(32'h224, 32'h0000_0024, "Illegal mepc+4");
        check_mem(32'h228, 32'hFFFF_FFFF, "Illegal mtval");
        check_mem(32'h240, 32'd3, "Exception trap count in memory");
        check_reg(5'd20, 32'd3, "Exception trap count in x20");

        $display("[Phase 1] Directed interrupts by source");
        load_irq_spin_program(32'h280, 32'h0000_0008); // MSI
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd2, 4);
        wait_cycles(120);
        check_mem(32'h280, CAUSE_IRQ_MSI, "MSI mcause");
        check_mem(32'h290, 32'h0000_0000, "MSI single-trap slot check");

        load_irq_spin_program(32'h2A0, 32'h0000_0080); // MTI
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd1, 4);
        wait_cycles(120);
        check_mem(32'h2A0, CAUSE_IRQ_MTI, "MTI mcause");
        check_mem(32'h2B0, 32'h0000_0000, "MTI single-trap slot check");

        load_irq_spin_program(32'h2C0, 32'h0000_0800); // MEI
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd0, 4);
        wait_cycles(120);
        check_mem(32'h2C0, CAUSE_IRQ_MEI, "MEI mcause");
        check_mem(32'h2D0, 32'h0000_0000, "MEI single-trap slot check");

        // ---------------------------
        // Phase 2: Mask/gating matrix
        // ---------------------------
        $display("[Phase 2] Masking/gating matrix");
        // Global off: no trap even if local enable + pending MEI
        load_mask_matrix_program(32'h0000_0800, 0);
        reset_cpu();
        wait_cycles(50);
        pulse_irq(2'd0, 6);
        wait_cycles(220);
        check_mem(32'h300, 32'h0000_0000, "MIE=0 blocks interrupt");

        // Local off: no trap if mie bit is disabled
        load_mask_matrix_program(32'h0000_0000, 1);
        reset_cpu();
        wait_cycles(50);
        pulse_irq(2'd0, 6);
        wait_cycles(220);
        check_mem(32'h300, 32'h0000_0000, "mie[MEIE]=0 blocks interrupt");

        // Both enabled: confirm trap is taken
        load_irq_spin_program(32'h300, 32'h0000_0800);
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd0, 6);
        wait_cycles(140);
        check_mem(32'h300, CAUSE_IRQ_MEI, "Enabled matrix mcause");
        check_mem(32'h310, 32'h0000_0000, "Enabled matrix single-trap slot");

        // ---------------------------
        // Phase 3: Priority + stress
        // ---------------------------
        $display("[Phase 3] Priority and back-to-back stress");
        // Simultaneous pending: MEI > MSI > MTI
        load_irq_spin_program(32'h380, 32'h0000_0888); // enable all
        reset_cpu();
        wait_cycles(80);
        meip = 1'b1;
        mtip = 1'b1;
        msip = 1'b1;
        wait_cycles(4);
        meip = 1'b0;
        mtip = 1'b0;
        msip = 1'b0;
        wait_cycles(140);
        check_mem(32'h380, CAUSE_IRQ_MEI, "Priority pick: MEI first");
        check_mem(32'h390, 32'h0000_0000, "Priority single-trap slot");

        // Back-to-back events
        load_irq_spin_program(32'h3C0, 32'h0000_0888); // enable all
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd0, 4); // MEI
        wait_cycles(140);
        mtip = 1'b1;         // Hold MTI level to guarantee visibility after MRET
        wait_cycles(120);
        mtip = 1'b0;
        wait_cycles(260);
        check_mem(32'h3C0, CAUSE_IRQ_MEI, "Back-to-back first cause");
        check_mem(32'h3D0, CAUSE_IRQ_MTI, "Back-to-back second cause");

        // ---------------------------
        // Phase 4: Timer IRQ + regression hooks
        // ---------------------------
        $display("[Phase 4] Timer interrupt (level-held mtip)");

        // Simulates timer compare-match: mtip is asserted as a level and
        // stays high until "software clears timecmp" (TB deasserts).
        // The handler sets x29 = 1 as a flag; after MRET, mainline code
        // detects x29 != 0 and exits the spin loop.
        load_timer_irq_program(32'h420);
        reset_cpu();
        wait_cycles(80);
        // Assert mtip level (simulates mtime >= mtimecmp)
        mtip = 1'b1;
        wait_cycles(120);
        // Deassert mtip (simulates handler writing new timecmp so mtime < mtimecmp)
        mtip = 1'b0;
        wait_cycles(200);
        check_mem(32'h420, CAUSE_IRQ_MTI, "Timer IRQ mcause");
        // Handler logged mstatus; verify MPIE was saved (bit 7 should be 1)
        // mstatus on trap entry: MIE=0, MPIE=1 (bit 7), MPP=11 (bits 12:11)
        // Expected: 0x00001880
        check_mem(32'h42C, 32'h0000_1880, "Timer IRQ mstatus.MPIE saved");
        // Confirm only one trap was taken
        check_mem(32'h430, 32'h0000_0000, "Timer IRQ single-trap slot");

        $display("[Phase 4] Regression smoke");
        // Keep a fast smoke sanity at end: MEI still functions with common handler.
        load_irq_spin_program(32'h440, 32'h0000_0800);
        reset_cpu();
        wait_cycles(80);
        pulse_irq(2'd0, 3);
        wait_cycles(120);
        check_mem(32'h440, CAUSE_IRQ_MEI, "Smoke MEI trap");
        check_mem(32'h450, 32'h0000_0000, "Smoke single-trap slot");

        $display("\n==============================================");
        $display("Trap TB Results: tests=%0d pass=%0d fail=%0d", test_count, pass_count, fail_count);
        $display("==============================================\n");
        if (fail_count == 0) begin
            $display("[PASS] z_core_trap_tb completed successfully.");
        end else begin
            $display("[FAIL] z_core_trap_tb found %0d failures.", fail_count);
        end
        $finish;
    end

endmodule
