`define TEST_MATRIX_DIM 2
/*
DIM==2:

-3  -15  x  9  -15 =     3   120
-6   7      -2 -5      -68    55

-3*9 + -15*-2 = -27 + 30 = 3
-3*-15 + -15*-5 = 45 + 75 = 120
-6*9 + 7*-2 = -54 + -14 = -68
-6*-15  + 7*-5 = 90 + -35 = 55

Correct!
*/

//`define TEST_MATRIX_DIM 16

module AI_Accelerator_Top_TB;

`include "verilog/benches/test_data/matrix_A.v"
`include "verilog/benches/test_data/matrix_B.v"

  // Parameters
  parameter CLK_PERIOD = 1;  // Clock period in ns
  
  // Inputs
  reg [31:0] wb_addr_i;
  reg wb_we_i;
  reg [31:0] wb_data_i;
  reg wb_stb;

  // Outputs
  wire [31:0] wb_data_o;
  wire wb_ack;
  
  // Instantiate the DUT
  AI_Accelerator_Top dut (
    .wb_clk_i(clk),
    .wb_rst_i(reset),
    .wb_addr_i(wb_addr_i),
    .wb_we_i(wb_we_i),
    .wb_data_i(wb_data_i),
    .wb_data_o(wb_data_o),
    .wb_ack(wb_ack),
    .wb_stb(wb_stb)
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
      wb_data_i = data;
      wb_addr_i = addr;
      #1;
      wb_stb = 1'b1;
      wb_we_i = 1'b1;
      @(posedge wb_ack);
      wb_stb = 1'b0;
      wb_we_i = 1'b0;
      #1;
      direction = 0;
      opdone = 1;
    end
    else if ( direction == 2 ) begin // Read
      opdone = 0;
      wb_we_i = 1'b0;
      wb_addr_i = addr;
      #1;
      wb_stb = 1'b1;
      @(posedge wb_ack);
      data = wb_data_o;
      wb_stb = 1'b0;
      #1;
      direction = 0;
      opdone = 1;
    end
  end

  // Initialize inputs
  initial begin

    wb_addr_i = 0;
    wb_we_i = 0;
    wb_data_i = 0;
    wb_stb <= 1'b0;
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

    #1000;

    data = 1;               // The operation to be executed
    addr = 0;
    direction = 1;          // Write operation
    @(posedge opdone);
    data = `TEST_MATRIX_DIM;// w_A
    addr = 1;
    direction = 1;          // Write operation
    @(posedge opdone);
    data = `TEST_MATRIX_DIM;// h_A
    addr = 2;
    direction = 1;          // Write operation
    @(posedge opdone);
    data = `TEST_MATRIX_DIM;// w_B
    addr = 3;
    direction = 1;          // Write operation
    @(posedge opdone);
    data = `TEST_MATRIX_DIM;// h_B
    addr = 4;
    direction = 1;          // Write operation
    @(posedge opdone);

    // Write data to matrix A and matrix B
    for (int i = 0; i < `TEST_MATRIX_DIM; i = i + 1) begin
      for (int j = 0; j < `TEST_MATRIX_DIM; j = j + 1) begin
        // Write data to matrix A
        addr = {2'b01, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = matrixA[i][j];
        direction = 1; // Write operation
        @(posedge opdone);
        //$display("Write address: %x, data: %d", addr, $signed(data));

        // Write data to matrix B
        addr = {2'b10, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = matrixB[i][j];
        direction = 1; // Write operation
        @(posedge opdone);
        //$display("Write address: %b, data: %d", addr, $signed(data));
      end
    end

    // Read data from matrix A and matrix B
    for (int i = 0; i < `TEST_MATRIX_DIM; i = i + 1) begin
      for (int j = 0; j < `TEST_MATRIX_DIM; j = j + 1) begin
        // Write data to matrix A
        addr = {2'b01, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        direction = 2; // Write operation
        @(posedge opdone);
        $display("matrixA[%d,%d] = %d", i, j, $signed(data));
        //$display("address: %x, data: %d", addr, $signed(data));

        // Write data to matrix B
        addr = {2'b10, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        direction = 2; // Write operation
        @(posedge opdone);
        $display("matrixB[%d,%d] = %d", i, j, $signed(data));
        //$display("Read address: %b, data: %d", addr, $signed(data));
      end
    end

    data = -1;  // OK. Go now
    addr = 5;
    direction = 1; // Write operation
    @(posedge opdone);

    // Read data from matrix C
    for (int i = 0; i < `TEST_MATRIX_DIM; i = i + 1) begin
      for (int j = 0; j < `TEST_MATRIX_DIM; j = j + 1) begin
        addr = {2'b11, i[`SEQ_BITS:0], j[`SEQ_BITS:0]}; // Address of matrix C
        direction = 2; // Read operation
        @(posedge opdone);
        $display("matrixC[%d,%d] = %d", i, j, $signed(data));
      end
    end

    #1000;  // Wait for a few clock cycles after the test case
    $finish;  // End the simulation

  end
  
endmodule
