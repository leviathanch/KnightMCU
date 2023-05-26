`define SEQ_BITS 14

module AI_Accelerator_Top_TB;

  // Parameters
  parameter CLK_PERIOD = 10;  // Clock period in ns
  
  // Inputs
  reg wishbone_clk_i;
  reg wishbone_rst_i;
  reg [31:0] wishbone_addr_i;
  reg wishbone_we_i;
  reg [31:0] wishbone_data_i;

  // Outputs
  wire [31:0] wishbone_data_o;
  wire wishbone_ack;
  
  // Instantiate the DUT
  AI_Accelerator_Top dut (
    .wishbone_clk_i(wishbone_clk_i),
    .wishbone_rst_i(wishbone_rst_i),
    .wishbone_addr_i(wishbone_addr_i),
    .wishbone_we_i(wishbone_we_i),
    .wishbone_data_i(wishbone_data_i),
    .wishbone_data_o(wishbone_data_o),
    .wishbone_ack(wishbone_ack)
  );
  
  // Clock generation
  always #((CLK_PERIOD / 2)) wishbone_clk_i = ~wishbone_clk_i;
  
  // Initialize inputs
  initial begin
    wishbone_clk_i = 0;
    wishbone_rst_i = 0;
    wishbone_addr_i = 0;
    wishbone_we_i = 0;
    wishbone_data_i = 0;

    // Dump signals to VCD file
    $dumpfile("waveform.vcd");
    $dumpvars(0, AI_Accelerator_Top_TB);

    // Write data to matrix A and matrix B
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        // Write data to matrix A
        wishbone_addr_i = {2'b01, i[`SEQ_BITS+1:0], j[`SEQ_BITS:0]};
        wishbone_we_i = 1'b1;        // Write operation
        wishbone_data_i = 32'hAAAA;  // Data to be written
        #10;                         // Wait for a few clock cycles
        //wishbone_ack = 1'b0;         // Deassert the acknowledgement signal

        // Write data to matrix B
        wishbone_addr_i = {2'b10, i[`SEQ_BITS+1:0], j[`SEQ_BITS:0]};
        wishbone_data_i = 32'h5555;  // Data to be written
        #10;                         // Wait for a few clock cycles
        //wishbone_ack = 1'b0;         // Deassert the acknowledgement signal
      end
    end

    // Read data from matrix C
    for (int i = 0; i <= `SEQ_BITS; i = i + 1) begin
      for (int j = 0; j <= `SEQ_BITS; j = j + 1) begin
        wishbone_addr_i = {2'b11, i[`SEQ_BITS+1:0], j[`SEQ_BITS:0]}; // Address of matrix C
        wishbone_we_i = 1'b0;        // Read operation
        #10;                         // Wait for a few clock cycles
        //wishbone_ack = 1'b0;         // Deassert the acknowledgement signal
      end
    end
    
    #100;  // Wait for a few clock cycles after the test case
    $finish;  // End the simulation
  end
  
  // Add stimulus and assertions here
  
endmodule
