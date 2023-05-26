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
    
    // Add your test case here
    
    #100;  // Wait for a few clock cycles after the test case
    $finish;  // End the simulation
  end
  
  // Add stimulus and assertions here
  
endmodule
