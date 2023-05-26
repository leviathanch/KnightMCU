`define SEQ_BITS 14

module AI_Accelerator_Top_TB;

  // Parameters
  parameter CLK_PERIOD = 1;  // Clock period in ns
  
  // Inputs
  reg [31:0] wishbone_addr_i;
  reg wishbone_we_i;
  reg [31:0] wishbone_data_i;
  reg wishbone_stb;

  // Outputs
  wire [31:0] wishbone_data_o;
  wire wishbone_ack;
  
  // Instantiate the DUT
  AI_Accelerator_Top dut (
    .wishbone_clk_i(clk),
    .wishbone_rst_i(reset),
    .wishbone_addr_i(wishbone_addr_i),
    .wishbone_we_i(wishbone_we_i),
    .wishbone_data_i(wishbone_data_i),
    .wishbone_data_o(wishbone_data_o),
    .wishbone_ack(wishbone_ack),
    .wishbone_stb(wishbone_stb)
  );

  // Clock generation
  reg clk;
  initial begin
    clk = 1;
    repeat (5000000) begin
      #1 clk = ~clk;
    end
  end
  
  // Reset
  reg reset;
  initial begin
    reset = 1;
    repeat (1) begin
      #20 reset = ~reset;
    end
  end

  // WB access job
  reg [31:0] data;
  reg [31:0] addr;
  integer direction;
  reg opdone;
  always @(posedge clk) begin
    if (direction == 1) begin // Write
      opdone = 0;
      wishbone_data_i = data;
      wishbone_addr_i = addr;
      #1;
      wishbone_stb = 1'b1;
      wishbone_we_i = 1'b1;
      @(posedge wishbone_ack);
      wishbone_stb = 1'b0;
      wishbone_we_i = 1'b0;
      #1;
      direction = 0;
      opdone = 1;
    end
    else if ( direction == 2 ) begin // Read
      opdone = 0;
      wishbone_we_i = 1'b0;
      wishbone_addr_i = addr;
      #1;
      wishbone_stb = 1'b1;
      @(posedge wishbone_ack);
      data = wishbone_data_o;
      wishbone_stb = 1'b0;
      #1;
      direction = 0;
      opdone = 1;
    end
  end

  // Initialize inputs
  initial begin
    wishbone_addr_i = 0;
    wishbone_we_i = 0;
    wishbone_data_i = 0;
    wishbone_stb <= 1'b0;
    data = 0;
    addr = 0;
    direction = 0;

    // Dump signals to VCD file
    $dumpfile("waveform.vcd");
    $dumpvars(0, AI_Accelerator_Top_TB);

    /* Operation registers at 0x00:
       0: operation
       1: width A
       2: height A
       3: width B
       4: height B
       5: done writing values, go! 
    */

    data = 1;      // The operation to be executed
    addr = 0;
    direction = 1; // Write operation
    @(posedge opdone);
    data = 15;     // w_A
    addr = 1;
    direction = 1; // Write operation
    @(posedge opdone);
    data = 15;     // h_A
    addr = 2;
    direction = 1; // Write operation
    @(posedge opdone);
    data = 15;     // w_B
    addr = 3;
    direction = 1; // Write operation
    @(posedge opdone);
    data = 15;     // h_B
    addr = 4;
    direction = 1; // Write operation
    @(posedge opdone);

    // Write data to matrix A and matrix B
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        // Write data to matrix A
        addr = {2'b01, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = i;  // Data to be written
        direction = 1; // Write operation
        @(posedge opdone);
        // Write data to matrix B
        addr = {2'b10, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = j;  // Data to be written
        direction = 1; // Write operation
        @(posedge opdone);
      end
    end

    #50;
    data = -1;  // OK. Go now
    addr = 5;
    direction = 1; // Write operation
    #50;

    // Read data from matrix C
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        addr = {2'b11, i[`SEQ_BITS+1:0], j[`SEQ_BITS:0]}; // Address of matrix C
        direction = 2; // Read operation
        @(posedge opdone);
        $display("C[%d,%d] = %x", i[`SEQ_BITS+1:0], j[`SEQ_BITS:0], data);
      end
    end

    #200000;  // Wait for a few clock cycles after the test case
    $finish;  // End the simulation

  end
  
endmodule
