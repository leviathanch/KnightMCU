module AI_Accelerator_Top #(
  parameter ADDR_OFFSET = 32'h3000_0000
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire         wbs_stb_i, // the strobe signal
  input wire         wbs_cyc_i,
  input wire         wbs_we_i,
  input wire [3:0]   wbs_sel_i,
  input wire [31:0]  wbs_adr_i,
  input wire [31:0]  wbs_dat_i,
  output wire         wbs_ack_o, // the readyness signal
  output wire [31:0]  wbs_dat_o,

  // Logic Analyzer Signals
  input  [127:0] la_data_in,
  output [127:0] la_data_out, // Debug LEDs pin [15:8]
  input  [127:0] la_oenb,

  // IOs
  input  [15:0] io_in,
  output [15:0] io_out,
  output [15:0] io_oeb,

  // IRQ
  output [2:0] irq
);

  // The clock net
  wire clk;

  // Logic Analyzer
  wire reset;

  // Parallelism
  wire [31:0] p;

  wire [3:0] sram_we;
  wire sram_en;
  wire [`KICP_SRAM_AWIDTH-1:0] sram_addr;
  wire [31:0] sram_data_i;
  wire [31:0] sram_data_o;

  RAM256 sram (
`ifdef USE_POWER_PINS
    .VPWR(vccd1),
    .VGND(vccd1),
`endif
    .CLK(clk),
    .WE0(sram_we),
    .EN0(sram_en),
    .Di0(sram_data_i),
    .Do0(sram_data_o),
    .A0(sram_addr)
  );

  /*
    Memory controller
  */
  wire mem_opdone;
  Memory_Controller mem_ctrl (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(clk),
    .reset(reset),
    
    .mem_opdone(mem_opdone),

    .sram_we(sram_we),
    .sram_en(sram_en),
    .sram_addr(sram_addr),
    .sram_data_i(sram_data_i),
    .sram_data_o(sram_data_o),

    // DMA access from Wishbone
    .wbctrl_mem_op(wbctrl_mem_op),
    .wbctrl_mem_addr(wbctrl_mem_addr),
    .wbctrl_mem_data(wbctrl_mem_data),
    .operation(operation),

    // DMA from Matrix multiplication core
    .mmul_mem_op(mmul_mem_op),
    .mmul_data(mmul_data),
    .mmul_addr(mmul_addr),

    // DMA from Matrix convolution core
    .mconv_mem_op(mconv_mem_op),
    .mconv_data(mconv_data),
    .mconv_addr(mconv_addr)
  );

  /*
    All the modules go here:
  */
  
  // Matrix multiplication
  Matrix_Multiplication matrix_mult (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(clk),
    .reset(reset),
    .enable(multiplier_enable),
    .done(matrix_mult_done),
    .addr_o(mmul_addr),
    .data_i(sram_data_o),
    .data_o(mmul_data),
    .mem_opdone(mem_opdone),
    .mem_operation(mmul_mem_op)
  );
  // Matrix multiplication result wire
  wire matrix_mult_done; // status wire
  wire [31:0] mmul_data;
  wire [31:0] mmul_addr;
  wire [1:0] mmul_mem_op; // Read 01 /Write 11 /None 00

  // Matrix Convolution
  Matrix_Convolution matrix_conv (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(clk),
    .reset(reset),
    .enable(convolution_enable),
    .done(matrix_conv_done),
    .addr_o(mconv_addr),
    .data_i(sram_data_o),
    .data_o(mconv_data),
    .mem_opdone(mem_opdone),
    .mem_operation(mconv_mem_op)
  );
  wire matrix_conv_done; // status wire
  wire [31:0] mconv_data;
  wire [31:0] mconv_addr;
  wire [1:0] mconv_mem_op; // Read 01 /Write 11 /None 00

  /*
    Control Unit
    Manages the current operation and changes the value
    in the status wireister
  */
  wire multiplier_enable;
  wire convolution_enable;
  wire finished;
  Control_Unit ctrl_unit (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(clk),
    .reset(reset),
    .operation(operation),
    .status(status),
    .matrix_mult_done(matrix_mult_done),
    .matrix_conv_done(matrix_conv_done),
    .multiplier_enable(multiplier_enable),
    .convolution_enable(convolution_enable),
    .finished(finished)
  );

  /*
    Wishbone slave controller.
    Manages read and write operations from master.
    Implemented by ChatGPT
  */
  // Status wireisters
  // 1: mutiply, 2: convolution
  wire [31:0] operation;
  // -1 for ready to start,
  //changes to error code or 0 for ok
  wire [31:0] status;

  wire [1:0] wbctrl_mem_op; // Read 01 /Write 11 /None 00
  wire [31:0] wbctrl_mem_addr;
  wire [31:0] wbctrl_mem_data;

  Wishbone_Slave_Controller #(ADDR_OFFSET) wb_slave_ctrl (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    // Wishbone
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wb_stb_i(wbs_stb_i),
    .wb_cyc_i(wbs_cyc_i),
    .wb_we_i(wbs_we_i),
    .wb_sel_i(wbs_sel_i),
    .wb_adr_i(wbs_adr_i),
    .wb_data_i(wbs_dat_i),
    .wb_data_o(wbs_dat_o),
    .wb_ack_o(wbs_ack_o),
    // DMA
    .sram_data(sram_data_o),
    // System
    .finished(finished),
    .status(status),
    .operation(operation),
    .mem_opdone(mem_opdone),
    .wbctrl_mem_op(wbctrl_mem_op),
    .wbctrl_mem_addr(wbctrl_mem_addr),
    .wbctrl_mem_data(wbctrl_mem_data),
    // System clock and reset
    .clk(clk),
    .reset(reset),
    // Logic Analyzer Signals
    .la_data_in(la_data_in),
    .la_data_out(la_data_out), // Debug LEDs pin [15:8]
    .la_oenb(la_oenb),
    // IOs
    .io_in(io_in),
    .io_out(io_out),
    .io_oeb(io_oeb),
    // IRQ
    .irq(irq)
  );
  
endmodule
