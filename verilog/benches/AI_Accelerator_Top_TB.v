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
      #5 clk = ~clk;
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
  reg direction;
  always @(posedge clk) begin
    if (direction) begin // Write
      wishbone_data_i = data;
      wishbone_addr_i = addr;
      #10;
      wishbone_stb = 1'b1;
      wishbone_we_i = 1'b1;
      @(posedge wishbone_ack);
      wishbone_stb = 1'b0;
      wishbone_we_i = 1'b0;
      #10;
    end
    else begin // Read
      wishbone_we_i = 1'b0;
      wishbone_addr_i = addr;
      #10;
      wishbone_stb = 1'b1;
      @(posedge wishbone_ack);
      wishbone_stb = 1'b0;
      #10;
      data = wishbone_data_o;
      #10;
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
    direction = 1; // Write operation

    #100;                  // Wait for a few clock cycles
    data = 32'h0000_0001;  // The operation to be executed
    addr = 0;
    #100;                  // Wait for a few clock cycles
    data = 32'h0000_000f;  // w_A
    addr = 1;
    #100;                  // Wait for a few clock cycles
    data = 32'h0000_000f;  // h_A
    addr = 2;
    #100;                  // Wait for a few clock cycles
    data = 32'h0000_000f;  // w_B
    addr = 3;
    #100;                  // Wait for a few clock cycles
    data = 32'h0000_000f;  // h_B
    addr = 4;
    #100;                  // Wait for a few clock cycles

    // Write data to matrix A and matrix B
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        // Write data to matrix A
        #100;
        addr = {2'b01, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = i*j;  // Data to be written
        // Write data to matrix B
        #100;
        addr = {2'b10, i[`SEQ_BITS:0], j[`SEQ_BITS:0]};
        data = i*(j+1)/2;  // Data to be written
      end
    end

    #100;
    data = 32'hffffffff;  // OK. Go now
    addr = 5;
    #100;

    // Read data from matrix C
    direction = 1'b0;        // Read operation

    @(posedge wishbone_ack);     // wait fo ACK
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        #100;
        addr = {2'b11, i[`SEQ_BITS+1:0], j[`SEQ_BITS:0]}; // Address of matrix C
        #100;
        $display("C[%d,%d] = %d", i[`SEQ_BITS+1:0], j[`SEQ_BITS:0], data);
      end
    end

    #100;  // Wait for a few clock cycles after the test case
    $finish;  // End the simulation

  end
  
endmodule
