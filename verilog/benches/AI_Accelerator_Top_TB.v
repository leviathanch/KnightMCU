module AI_Accelerator_Top_TB;

  // Parameters
  parameter CLK_PERIOD = 10;  // Clock period in ns
  
  // Inputs
  reg clk;
  reg reset;
  reg enable;
  reg wishbone_clk_i;
  reg wishbone_rst_i;
  reg [31:0] wishbone_addr_i;
  reg wishbone_we_i;
  reg [31:0] wishbone_data_i;

  // Outputs
  wire [31:0] wishbone_data_o;
  
  // Instantiate the DUT
  AI_Accelerator_Top dut (
    .clk(clk),
    .reset(reset),
    .wishbone_clk_i(wishbone_clk_i),
    .wishbone_rst_i(wishbone_rst_i),
    .wishbone_addr_i(wishbone_addr_i),
    .wishbone_we_i(wishbone_we_i),
    .wishbone_data_i(wishbone_data_i),
    .wishbone_data_o(wishbone_data_o)
  );
  
  // Clock generation
  always #((CLK_PERIOD / 2)) clk = ~clk;
  
  // Initialize inputs
  initial begin
    clk = 0;
    reset = 0;
    enable = 0;
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
