`timescale 1ns/1ps

module z_core_write_buffer_tb;

localparam DATA_WIDTH = 32;
localparam ADDR_WIDTH = 32;
localparam ENTRIES = 8;

reg clk;
reg rstn;
reg [DATA_WIDTH-1:0] write_back_data;
reg [ADDR_WIDTH-1:0] write_back_addr;
reg [3:0] write_back_strb;
reg write_enable;
reg read_enable;
reg [ADDR_WIDTH-1:0] load_address;
reg load_check;

wire [DATA_WIDTH-1:0] wb_out_data;
wire [DATA_WIDTH-1:0] wb_out_address;
wire [3:0] wb_out_strb;
wire wb_out_valid;
wire full_out;
wire empty_out;
wire [DATA_WIDTH-1:0] load_forward_out;
wire load_forward_valid_out;
wire [3:0] load_forward_strb_out;

integer errors;
integer i;

z_core_write_buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .ENTRIES(ENTRIES)
) dut (
    .clk(clk),
    .rstn(rstn),
    .write_back_data(write_back_data),
    .write_back_addr(write_back_addr),
    .write_back_strb(write_back_strb),
    .write_enable(write_enable),
    .read_enable(read_enable),
    .load_address(load_address),
    .load_check(load_check),
    .wb_out_data(wb_out_data),
    .wb_out_address(wb_out_address),
    .wb_out_strb(wb_out_strb),
    .wb_out_valid(wb_out_valid),
    .full_out(full_out),
    .empty_out(empty_out),
    .load_forward_out(load_forward_out),
    .load_forward_valid_out(load_forward_valid_out),
    .load_forward_strb_out(load_forward_strb_out)
);

always #5 clk = ~clk;

task automatic check(input condition, input string name);
begin
    if (!condition) begin
        $display("FAIL: %s", name);
        errors = errors + 1;
    end
end
endtask

task automatic reset_dut;
begin
    rstn = 0;
    write_enable = 0;
    read_enable = 0;
    load_check = 0;
    write_back_strb = 4'b1111;
    repeat (2) @(posedge clk);
    #1;
    rstn = 1;
end
endtask

task automatic enqueue(
    input [ADDR_WIDTH-1:0] address,
    input [DATA_WIDTH-1:0] data
);
begin
    @(negedge clk);
    write_back_addr = address;
    write_back_data = data;
    write_back_strb = 4'b1111;
    write_enable = 1;
    @(posedge clk);
    #1;
    write_enable = 0;
end
endtask

task automatic dequeue(
    input [ADDR_WIDTH-1:0] expected_address,
    input [DATA_WIDTH-1:0] expected_data
);
begin
    @(negedge clk);
    read_enable = 1;
    @(posedge clk);
    #1;
    if (wb_out_valid !== 1'b1) begin
        $display("FAIL: dequeue %h valid", expected_address);
        errors = errors + 1;
    end
    if (wb_out_address !== expected_address) begin
        $display(
            "FAIL: dequeue address expected=%h actual=%h",
            expected_address,
            wb_out_address
        );
        errors = errors + 1;
    end
    if (wb_out_data !== expected_data) begin
        $display(
            "FAIL: dequeue %h data expected=%h actual=%h",
            expected_address,
            expected_data,
            wb_out_data
        );
        errors = errors + 1;
    end
    if (wb_out_strb !== 4'b1111) begin
        $display(
            "FAIL: dequeue %h strb expected=1111 actual=%b",
            expected_address,
            wb_out_strb
        );
        errors = errors + 1;
    end
    read_enable = 0;
end
endtask

task automatic expect_forward(
    input [ADDR_WIDTH-1:0] address,
    input [DATA_WIDTH-1:0] expected_data,
    input expected_valid,
    input string name
);
begin
    load_address = address;
    load_check = 1;
    #1;
    if (load_forward_valid_out !== expected_valid) begin
        $display("FAIL: %s valid", name);
        errors = errors + 1;
    end
    if (expected_valid && load_forward_out !== expected_data) begin
        $display("FAIL: %s data", name);
        errors = errors + 1;
    end
    if (load_forward_strb_out !== (expected_valid ? 4'b1111 : 4'b0000)) begin
        $display("FAIL: %s strb", name);
        errors = errors + 1;
    end
    load_check = 0;
    #1;
end
endtask

task automatic simultaneous_transfer(
    input [ADDR_WIDTH-1:0] expected_address,
    input [DATA_WIDTH-1:0] expected_data,
    input [ADDR_WIDTH-1:0] new_address,
    input [DATA_WIDTH-1:0] new_data,
    input string name
);
begin
    @(negedge clk);
    read_enable = 1;
    write_enable = 1;
    write_back_addr = new_address;
    write_back_data = new_data;
    write_back_strb = 4'b1111;
    @(posedge clk);
    #1;
    if (wb_out_valid !== 1'b1) begin
        $display("FAIL: %s valid", name);
        errors = errors + 1;
    end
    if (wb_out_address !== expected_address) begin
        $display("FAIL: %s address", name);
        errors = errors + 1;
    end
    if (wb_out_data !== expected_data) begin
        $display("FAIL: %s data", name);
        errors = errors + 1;
    end
    if (wb_out_strb !== 4'b1111) begin
        $display("FAIL: %s strb", name);
        errors = errors + 1;
    end
    read_enable = 0;
    write_enable = 0;
end
endtask

initial begin
    $dumpfile("z_core_write_buffer_tb.vcd");
    $dumpvars(0, z_core_write_buffer_tb);
    
    clk = 0;
    rstn = 1;
    write_back_data = 0;
    write_back_addr = 0;
    write_back_strb = 4'b1111;
    write_enable = 0;
    read_enable = 0;
    load_address = 32'hffff_ffff;
    load_check = 0;
    errors = 0;

    reset_dut();
    check(empty_out === 1'b1, "empty after reset");
    check(full_out === 1'b0, "not full after reset");
    check(wb_out_valid === 1'b0, "output invalid after reset");
    check(load_forward_valid_out === 1'b0, "forward miss after reset");

    @(negedge clk);
    read_enable = 1;
    @(posedge clk);
    #1;
    read_enable = 0;
    check(empty_out === 1'b1, "empty read does not underflow");

    reset_dut();
    enqueue(32'h1000, 32'h1111_1111);
    enqueue(32'h1004, 32'h2222_2222);
    load_address = 32'h1004;
    load_check = 1;
    #1;
    check(load_forward_valid_out === 1'b1, "forward hit valid");
    check(load_forward_out === 32'h2222_2222, "forward hit data");
    load_check = 0;

    dequeue(32'h1000, 32'h1111_1111);
    enqueue(32'h1008, 32'h3333_3333);
    check(wb_out_valid === 1'b0, "output invalid during enqueue");
    dequeue(32'h1004, 32'h2222_2222);
    dequeue(32'h1008, 32'h3333_3333);
    check(empty_out === 1'b1, "empty after draining");

    load_address = 32'h1000;
    load_check = 1;
    #1;
    check(load_forward_valid_out === 1'b0, "dequeued store not forwarded");
    load_address = 32'hdead_beef;
    #1;
    check(load_forward_valid_out === 1'b0, "forward miss invalid");
    load_check = 0;

    reset_dut();
    for (i = 0; i < ENTRIES; i = i + 1)
        enqueue(32'h2000 + i * 4, 32'ha000_0000 + i);
    check(full_out === 1'b1, "full after ENTRIES writes");

    enqueue(32'hffff_0000, 32'hffff_0000);
    check(full_out === 1'b1, "full write does not overflow");

    reset_dut();
    for (i = 0; i < ENTRIES; i = i + 1)
        enqueue(32'h2000 + i * 4, 32'ha000_0000 + i);

    @(negedge clk);
    read_enable = 1;
    write_enable = 1;
    write_back_addr = 32'h3000;
    write_back_data = 32'hbbbb_bbbb;
    @(posedge clk);
    #1;
    check(wb_out_valid === 1'b1, "simultaneous read valid");
    check(wb_out_address === 32'h2000, "simultaneous read address");
    check(wb_out_data === 32'ha000_0000, "simultaneous read data");
    check(full_out === 1'b1, "count stable on simultaneous read and write");

    @(negedge clk);
    write_back_addr = 32'h3004;
    write_back_data = 32'hcccc_cccc;
    @(posedge clk);
    #1;
    check(wb_out_valid === 1'b1, "second simultaneous read valid");
    check(wb_out_address === 32'h2004, "second simultaneous read address");
    check(wb_out_data === 32'ha000_0001, "second simultaneous read data");
    read_enable = 0;
    write_enable = 0;

    for (i = 2; i < ENTRIES; i = i + 1)
        dequeue(32'h2000 + i * 4, 32'ha000_0000 + i);
    dequeue(32'h3000, 32'hbbbb_bbbb);
    dequeue(32'h3004, 32'hcccc_cccc);
    check(empty_out === 1'b1, "empty after simultaneous transfer");

    reset_dut();
    enqueue(32'h4000, 32'h1111_0000);
    enqueue(32'h4000, 32'h2222_0000);
    expect_forward(32'h4000, 32'h2222_0000, 1'b1, "basic merge forwarding");
    dequeue(32'h4000, 32'h2222_0000);
    check(empty_out === 1'b1, "basic merge occupies one entry");

    reset_dut();
    enqueue(32'h4100, 32'haaaa_0000);
    enqueue(32'h4104, 32'hbbbb_0000);
    enqueue(32'h4108, 32'hcccc_0000);
    enqueue(32'h4104, 32'hbbbb_1111);
    expect_forward(32'h4104, 32'hbbbb_1111, 1'b1, "non-tail newest forwarding");
    dequeue(32'h4100, 32'haaaa_0000);
    dequeue(32'h4104, 32'hbbbb_0000);
    dequeue(32'h4108, 32'hcccc_0000);
    dequeue(32'h4104, 32'hbbbb_1111);
    check(empty_out === 1'b1, "non-tail match appends");

    reset_dut();
    enqueue(32'h4200, 32'haaaa_2222);
    enqueue(32'h4204, 32'hbbbb_2222);
    enqueue(32'h4200, 32'hcccc_2222);
    expect_forward(32'h4200, 32'hcccc_2222, 1'b1, "head match newest forwarding");
    dequeue(32'h4200, 32'haaaa_2222);
    dequeue(32'h4204, 32'hbbbb_2222);
    dequeue(32'h4200, 32'hcccc_2222);
    check(empty_out === 1'b1, "head match appends");

    reset_dut();
    for (i = 0; i < ENTRIES; i = i + 1)
        enqueue(32'h5000 + i * 4, 32'h5000_0000 + i);
    check(full_out === 1'b1, "full before merge");

    @(negedge clk);
    write_back_addr = 32'h500c;
    write_back_data = 32'hface_0003;
    write_enable = 1;
    load_address = 32'h500c;
    load_check = 1;
    #1;
    check(load_forward_valid_out === 1'b1, "full non-tail lookup valid");
    check(load_forward_out === 32'h5000_0003, "full non-tail write rejected");
    @(posedge clk);
    #1;
    write_enable = 0;
    load_check = 0;
    check(full_out === 1'b1, "rejected full write keeps occupancy");

    for (i = 0; i < ENTRIES; i = i + 1)
        dequeue(32'h5000 + i * 4, 32'h5000_0000 + i);
    check(empty_out === 1'b1, "full non-tail write changes nothing");

    reset_dut();
    for (i = 0; i < ENTRIES; i = i + 1)
        enqueue(32'h5100 + i * 4, 32'h5100_0000 + i);

    @(negedge clk);
    write_back_addr = 32'h511c;
    write_back_data = 32'hfeed_0007;
    write_enable = 1;
    load_address = 32'h511c;
    load_check = 1;
    #1;
    check(load_forward_valid_out === 1'b1, "full tail merge forward valid");
    check(load_forward_out === 32'hfeed_0007, "full tail merge forward data");
    @(posedge clk);
    #1;
    write_enable = 0;
    load_check = 0;
    check(full_out === 1'b1, "full tail merge keeps occupancy");

    for (i = 0; i < ENTRIES; i = i + 1) begin
        if (i == ENTRIES - 1)
            dequeue(32'h5100 + i * 4, 32'hfeed_0007);
        else
            dequeue(32'h5100 + i * 4, 32'h5100_0000 + i);
    end
    check(empty_out === 1'b1, "full tail merge drains once");

    reset_dut();
    write_back_addr = 32'hdead_c0de;
    write_back_data = 32'hffff_ffff;
    write_enable = 0;
    expect_forward(32'hdead_c0de, 32'h0000_0000, 1'b0, "idle write not forwarded");

    @(negedge clk);
    write_back_addr = 32'h4300;
    write_back_data = 32'h1234_5678;
    write_enable = 1;
    load_address = 32'h4300;
    load_check = 1;
    #1;
    check(load_forward_valid_out === 1'b1, "accepted write forward valid");
    check(load_forward_out === 32'h1234_5678, "accepted write forward data");
    @(posedge clk);
    #1;
    write_enable = 0;
    load_check = 0;
    dequeue(32'h4300, 32'h1234_5678);
    check(empty_out === 1'b1, "accepted write stored once");

    reset_dut();
    enqueue(32'h4400, 32'haaaa_4400);
    enqueue(32'h4404, 32'hbbbb_4404);
    enqueue(32'h4408, 32'hcccc_4408);
    simultaneous_transfer(
        32'h4400,
        32'haaaa_4400,
        32'h4404,
        32'hdddd_4404,
        "pop plus non-tail write"
    );
    dequeue(32'h4404, 32'hbbbb_4404);
    dequeue(32'h4408, 32'hcccc_4408);
    dequeue(32'h4404, 32'hdddd_4404);
    check(empty_out === 1'b1, "pop plus non-tail write keeps occupancy");

    reset_dut();
    enqueue(32'h4500, 32'haaaa_4500);
    enqueue(32'h4504, 32'hbbbb_4504);
    simultaneous_transfer(
        32'h4500,
        32'haaaa_4500,
        32'h4500,
        32'hcccc_4500,
        "merge target being read"
    );
    dequeue(32'h4504, 32'hbbbb_4504);
    dequeue(32'h4500, 32'hcccc_4500);
    check(empty_out === 1'b1, "head replacement appends at tail");

    reset_dut();
    enqueue(32'h6100, 32'h6100_0000);
    enqueue(32'h6104, 32'h6100_0001);
    enqueue(32'h6108, 32'h6100_0002);
    enqueue(32'h610c, 32'h6100_0003);
    enqueue(32'h6110, 32'h6100_0004);
    enqueue(32'h6114, 32'h6100_0005);
    dequeue(32'h6100, 32'h6100_0000);
    dequeue(32'h6104, 32'h6100_0001);
    dequeue(32'h6108, 32'h6100_0002);
    dequeue(32'h610c, 32'h6100_0003);
    enqueue(32'h6200, 32'h6200_0000);
    enqueue(32'h6204, 32'h6200_0001);
    enqueue(32'h6208, 32'h6200_0002);
    enqueue(32'h620c, 32'h6200_0003);
    enqueue(32'h6208, 32'hbeef_6208);
    expect_forward(32'h6208, 32'hbeef_6208, 1'b1, "wrapped append forwarding");
    dequeue(32'h6110, 32'h6100_0004);
    dequeue(32'h6114, 32'h6100_0005);
    dequeue(32'h6200, 32'h6200_0000);
    dequeue(32'h6204, 32'h6200_0001);
    dequeue(32'h6208, 32'h6200_0002);
    dequeue(32'h620c, 32'h6200_0003);
    dequeue(32'h6208, 32'hbeef_6208);
    check(empty_out === 1'b1, "wrapped non-tail match appends");

    reset_dut();
    enqueue(32'h7000, 32'haaaa_7000);
    simultaneous_transfer(
        32'h7000,
        32'haaaa_7000,
        32'h7000,
        32'hbbbb_7000,
        "one-entry pop plus same-address push"
    );
    check(empty_out === 1'b0, "one-entry replacement remains queued");
    dequeue(32'h7000, 32'hbbbb_7000);
    check(empty_out === 1'b1, "one-entry replacement drains once");

    if (errors == 0) begin
        $display("PASS");
        $finish;
    end else begin
        $fatal(1, "FAIL: %0d checks failed", errors);
    end
end

endmodule
