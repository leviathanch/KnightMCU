module Wishbone_Slave_Controller
#(
  parameter ADDR_OFFSET = 32'h3000_0000
)
(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  // Wishbone
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire         wb_stb_i, // the strobe signal
  input wire         wb_cyc_i,
  input wire         wb_we_i,
  input wire [3:0]   wb_sel_i,
  input wire [31:0]  wb_adr_i,
  input wire [31:0]  wb_data_i,
  output reg         wb_ack_o, // the readyness signal
  output reg [31:0]  wb_data_o,
  // System
  input wire mem_opdone,
  input wire finished,
  output reg [31:0] status,
  output reg [31:0] operation,
  output reg [1:0] wbctrl_mem_op, // Read 01 /Write 11 /None 00
  output reg [31:0] wbctrl_mem_addr,
  output reg [31:0] wbctrl_mem_data,
  output wire clk,
  output wire reset,
  // DMA
  input wire [31:0] sram_data,

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

  assign reset = wb_rst_i;
  assign clk = wb_clk_i;
  assign la_data_out = {{(127-64){1'b0}}, wbctrl_addr_buf, wbctrl_data_buf};
  assign io_out = {operation[1:0],{(15-2){1'b0}}};
  // IRQ
  assign irq = 3'b000;	// Unused
  // IO
  wire rst;
  assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;
  assign io_oeb = {(15){rst}};

  integer wb_state;
  output reg [31:0] wbctrl_addr_buf;
  output reg [31:0] wbctrl_data_buf;

  localparam IDLE = 0;
  localparam WRITE = 1;
  localparam READ = 2;
  localparam WAIT_READ = 3;
  localparam WAIT_READ_DONE = 4;
  localparam WAIT_WRITE_DONE = 5;
  localparam READ_DONE = 6;
  localparam WRITE_DONE = 7;

  always @(posedge clk) begin
    if (reset) begin
      wb_state <= IDLE;
      wb_ack_o <= 1'b0;
      wb_data_o <= 32'b0;
      wbctrl_mem_op <= 2'b00;
      wbctrl_mem_addr <= 32'b0;
      wbctrl_mem_data <= 32'b0;
      wbctrl_addr_buf <= 32'b0;
      wbctrl_data_buf <= 32'b0;
      status <= 0;
      operation <= 0;
    end
    else if (finished) begin
      status <= 0;
    end
    else begin
      case (wb_state)
        IDLE: begin // Idle state
          wb_ack_o <= 1'b0;
          if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            wbctrl_addr_buf <= wb_adr_i;
            wbctrl_data_buf <= wb_data_i;
            wb_data_o <= 32'h0000_0000;
            if (wb_we_i) begin // Writing requested
              wb_state <= WRITE; // Write state
            end else begin // Reading requested
              wb_state <= READ; // Read state
            end
          end
        end
        READ: begin // Read state
          // increments of 1 become 4 because 32 int32_t = 4 bytes:
          if( (wbctrl_addr_buf-ADDR_OFFSET) == 0) begin
            wb_data_o <= operation;
            wb_state <= READ_DONE; // Read done
            wbctrl_mem_addr <= 0;
          end
          else if( (wbctrl_addr_buf-ADDR_OFFSET) == 4 ) begin
            wb_data_o <= status;
            wb_state <= READ_DONE; // Read done
            wbctrl_mem_addr <= 0;
          end
          else begin
            wbctrl_mem_op <= 2'b01;
            wbctrl_mem_addr <= (wbctrl_addr_buf-ADDR_OFFSET)/4-2;
            wb_state <= WAIT_READ_DONE; // Read state
          end
        end
        WRITE: begin // Write state
          // increments of 1 become 4 because 32 int32_t = 4 bytes:
          if( (wbctrl_addr_buf-ADDR_OFFSET) == 0 ) begin
            operation <= wbctrl_data_buf;
            wb_state <= WRITE_DONE; // Write done
            wbctrl_mem_addr <= 0;
          end
          else if( (wbctrl_addr_buf-ADDR_OFFSET) == 4 ) begin
            status <= wbctrl_data_buf;
            wb_state <= WRITE_DONE; // Write done
            wbctrl_mem_addr <= 0;
          end
          else begin
            wbctrl_mem_op <= 2'b11;
            wbctrl_mem_data <= wbctrl_data_buf;
            wbctrl_mem_addr <= (wbctrl_addr_buf-ADDR_OFFSET)/4-2;
            wb_state <= WAIT_WRITE_DONE; // Wait for write finished
          end
        end
        WAIT_READ_DONE: begin // Wait for reading done
          if ( mem_opdone ) begin
            wb_data_o <= sram_data;
            wbctrl_mem_op <= 2'b00;
            wb_state <= READ_DONE; // Go to read done
          end
        end
        READ_DONE: begin // Read done
          //$display("Read %d from %x (%x)", $signed(wb_data_o), wbctrl_mem_addr, wbctrl_addr_buf);
          wb_ack_o <= 1'b1;
          wb_state <= IDLE; // Return to Idle stat
        end
        WAIT_WRITE_DONE: begin // Wait write for done
          if ( mem_opdone ) begin
            wbctrl_mem_op <= 2'b00;
            wb_state <= WRITE_DONE; // Write done
          end
        end
        WRITE_DONE: begin // Wait write for done
          //$display("Wrote %d to %x (%x)", $signed(wbctrl_data_buf), wbctrl_mem_addr, wbctrl_addr_buf);
          wb_ack_o <= 1'b1;
          wb_state <= IDLE; // Return to Idle state
        end
      endcase
    end
  end
endmodule
