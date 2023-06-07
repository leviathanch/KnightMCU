module Memory_Controller (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  input wire clk,
  input wire reset,
  output reg mem_opdone,
  output reg [3:0] sram_we,
  output reg sram_en,
  output reg [`KICP_SRAM_AWIDTH-1:0] sram_addr,
  output reg [31:0] sram_data_i,
  input wire [31:0] sram_data_o,

  // DMA access from Wishbone
  input wire [1:0] wbctrl_mem_op,
  input wire [31:0] wbctrl_mem_addr,
  input wire [31:0] wbctrl_mem_data,
  input wire [31:0] operation,

  // DMA from Matrix multiplication core
  input wire [1:0] mmul_mem_op, // Read 01 /Write 11 /None 00
  input wire [31:0] mmul_data,
  input wire [`KICP_SRAM_AWIDTH-1:0] mmul_addr,

  // DMA from Matrix convolution core
  input wire [1:0] mconv_mem_op, // Read 01 /Write 11 /None 00
  input wire [31:0] mconv_data,
  input wire [`KICP_SRAM_AWIDTH-1:0] mconv_addr
  
);
  reg mem_read_wait;
  reg mem_write_wait;
  reg [1:0] mem_ctl_state;

  always @(posedge clk) begin
    if (reset) begin
      mem_opdone <= 0;
      sram_we <= 4'b0000;
      sram_en <= 0;
      mem_write_wait <= 0;
      mem_read_wait <= 0;
      sram_we <= 4'b0000;
      sram_en <= 0;
    end
    else if ( mem_read_wait ) begin
      if( sram_addr != sram_data_o ) begin
        mem_opdone <= 1;
        mem_read_wait  <= 0;
        sram_en <= 0;
        sram_we <= 4'b0000;
      end
    end
    else if ( mem_write_wait ) begin
      if( sram_data_i == sram_data_o ) begin
        mem_opdone <= 1;
        mem_write_wait  <= 0;
        sram_we <= 4'b0000;
        sram_en <= 0;
      end
    end
    else if ( mem_opdone ) begin
      mem_opdone <= 0;
    end
    else if (! mem_opdone ) begin
      if ( wbctrl_mem_op == 2'b01 ) begin // Read
          sram_we <= 4'b0000;
          sram_en <= 1;
          sram_addr <= wbctrl_mem_addr;
          mem_read_wait <= 1;
          //$display("WB reading %x", wbctrl_mem_addr);
      end
      else if ( wbctrl_mem_op == 2'b11 ) begin // Write
          sram_we <= 4'b1111;
          sram_en <= 1;
          sram_addr <= wbctrl_mem_addr;
          sram_data_i <= wbctrl_mem_data;
          mem_write_wait <= 1;
          //$display("WB writing %x", wbctrl_mem_addr);
      end
      else begin
        case ( operation ) // Register 1 holds the operation to be executed
          // Enable corresponding module based on operation value in operation register
          `MULTIPLICATION_OPERATION: begin // matrix multiplication
            case (mmul_mem_op)
              2'b01: begin // Read
                sram_en <= 1;
                sram_addr <= mmul_addr[`KICP_SRAM_AWIDTH-1:0];
                mem_read_wait <= 1;
              end
              2'b11: begin // Write
                sram_we <= 4'b1111;
                sram_en <= 1;
                sram_addr <= mmul_addr[`KICP_SRAM_AWIDTH-1:0];
                sram_data_i <= mmul_data;
                mem_write_wait <= 1;
                //$display("Got result %d for address %x", $signed(mmul_data), mmul_addr);
              end
            endcase
          end
          `CONVOLUTION_OPERATION: begin // matrix convolution
            case (mconv_mem_op)
              2'b01: begin // Read
                sram_en <= 1;
                sram_addr <= mconv_addr[`KICP_SRAM_AWIDTH-1:0];
                mem_read_wait <= 1;
              end
              2'b11: begin // Write
                sram_we <= 4'b1111;
                sram_en <= 1;
                sram_addr <= mconv_addr[`KICP_SRAM_AWIDTH-1:0];
                sram_data_i <= mconv_data;
                mem_write_wait <= 1;
                //$display("Got result %d for address %x", $signed(mconv_data), mconv_addr);
              end
            endcase
          end
        endcase
      end
    end
  end
endmodule
