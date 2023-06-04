module AI_Accelerator_Top #(
  parameter ADDR_OFFSET = 32'h3000_0000
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire         wb_stb, // the strobe signal
  input wire         wb_cyc_i,
  input wire         wb_we_i,
  input wire [3:0]   wbs_sel_i,
  input wire [31:0]  wb_addr_i,
  input wire [31:0]  wb_data_i,
  output reg         wb_ack, // the readyness signal
  output reg [31:0]  wb_data_o,

  // Logic Analyzer Signals
  input  wire [127:0] la_data_in,
  output wire [127:0] la_data_out,
  input  wire [127:0] la_oenb,

  // IOs
  input wire [15:0] io_in,
  output wire [15:0] io_out, // Debug LEDs pin [15:8]
  output wire [15:0] io_oeb
);
  
  // Parallelism
  reg [31:0] p;

  // Status registers
  // 1: mutiply, 2: convolution
  reg [31:0] operation;
  // -1 for ready to start,
  //changes to error code or 0 for ok
  reg [31:0] status;
  reg [3:0] sram_we;
  reg sram_en;
  reg [`KICP_SRAM_AWIDTH-1:0] sram_addr;
  reg [31:0] sram_data_i;
  wire [31:0] sram_data_o;

  RAM256 sram (
`ifdef USE_POWER_PINS
    .VPWR(vccd1),
    .VGND(vccd1),
`endif
    .CLK(wb_clk_i),
    .WE0(sram_we),
    .EN0(sram_en),
    .Di0(sram_data_i),
    .Do0(sram_data_o),
    .A0(sram_addr)
  );
  
  /*
    Memory controller
  */
  reg mem_read_wait;
  reg mem_write_wait;
  reg mem_opdone;
  reg [1:0] mem_ctl_state;

  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      mem_opdone <= 0;
      sram_we <= 4'b0000;
      sram_en <= 0;
      operation <= 0;
      status <= 0;
      mem_write_wait <= 0;
      mem_read_wait <= 0;
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
          `TYPE_BW'h1: begin // matrix multiplication
            case (mmul_mem_op)
              2'b01: begin // Read
                sram_en <= 1;
                sram_addr <= mmul_addr_o[`KICP_SRAM_AWIDTH-1:0];
                mem_read_wait <= 1;
              end
              2'b11: begin // Write
                sram_we <= 4'b1111;
                sram_en <= 1;
                sram_addr <= mmul_addr_o[`KICP_SRAM_AWIDTH-1:0];
                sram_data_i <= mmul_data_o;
                mem_write_wait <= 1;
                //$display("Got result %d for address %x", $signed(mmul_data_o), mmul_addr_o);
              end
            endcase
          end
          `TYPE_BW'h2: begin // matrix convolution
            case (mconv_mem_op)
              2'b01: begin // Read
                sram_en <= 1;
                sram_addr <= mconv_addr_o[`KICP_SRAM_AWIDTH-1:0];
                mem_read_wait <= 1;
              end
              2'b11: begin // Write
                sram_we <= 4'b1111;
                sram_en <= 1;
                sram_addr <= mconv_addr_o[`KICP_SRAM_AWIDTH-1:0];
                sram_data_i <= mconv_data_o;
                mem_write_wait <= 1;
                //$display("Got result %d for address %x", $signed(mconv_data_o), mconv_addr_o);
              end
            endcase
          end
        endcase
      end
    end
  end

  /*
    All the modules go here:
  */
  
  // Matrix multiplication
  Matrix_Multiplication matrix_mult (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(multiplier_enable),
    .done(matrix_mult_done),
    .addr_o(mmul_addr_o),
    .data_i(sram_data_o),
    .data_o(mmul_data_o),
    .mem_opdone(mem_opdone),
    .mem_operation(mmul_mem_op)
  );
  // Matrix multiplication result wire
  reg multiplier_enable; // on switch
  wire matrix_mult_done; // status wire
  wire [`TYPE_BW-1:0] mmul_data_o;
  wire [31:0] mmul_addr_o;
  wire [1:0] mmul_mem_op; // Read 01 /Write 11 /None 00

  // Matrix Convolution
  Matrix_Convolution matrix_conv (
`ifdef USE_POWER_PINS
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(convolution_enable),
    .done(matrix_conv_done),
    .addr_o(mconv_addr_o),
    .data_i(sram_data_o),
    .data_o(mconv_data_o),
    .mem_opdone(mem_opdone),
    .mem_operation(mconv_mem_op)
  );
  reg convolution_enable; // on switch
  wire matrix_conv_done; // status wire
  wire [`TYPE_BW-1:0] mconv_data_o;
  wire [31:0] mconv_addr_o;
  wire [1:0] mconv_mem_op; // Read 01 /Write 11 /None 00
  
  /*
    Control Unit
    Manages the current operation and changes the value
    in the status register
  */
  reg busy;
  reg started;
  reg finished;
  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0;
      convolution_enable <= 1'b0;
      finished <= 0;
    end
    else if ( started && busy ) begin
      started <= 0;
    end
    else if ( status == `TYPE_BW'h0000_0000 && finished ) begin
       finished <= 0;
    end
    else if ( !finished ) begin
      case ( operation ) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          if( matrix_mult_done && busy ) begin
            busy <= 1'b0;
            multiplier_enable <= 1'b0; // Enable matrix multiplication module
            finished <= 1; // Done
          end
          else if ( status == `TYPE_BW'hffff_ffff ) begin
            busy <= 1'b1; // indicate that we started operation
            multiplier_enable <= 1'b1; // Enable matrix multiplication module
            started <= 1'b1;
          end
        end
        `TYPE_BW'h2: begin // matrix convolution
          if( matrix_conv_done && busy ) begin
            busy <= 1'b0;
            convolution_enable <= 1'b0; // Enable matrix multiplication module
            finished <= 1; // Done
          end
          else if ( status == `TYPE_BW'hffff_ffff ) begin
            busy <= 1'b1; // indicate that we started operation
            convolution_enable <= 1'b1; // Enable matrix multiplication module
            started <= 1'b1;
          end
        end
      endcase
    end
  end

  /*
    Wishbone slave controller.
    Manages read and write operations from master.
    Implemented by ChatGPT
  */
  reg [1:0] wbctrl_mem_op; // Read 01 /Write 11 /None 00
  reg [31:0] wbctrl_mem_addr;
  reg [31:0] wbctrl_mem_data;
  reg [31:0] wbctrl_addr_buf;
  reg [31:0] wbctrl_data_buf;

  integer wb_state;

  localparam IDLE = 0;
  localparam WRITE = 1;
  localparam READ = 2;
  localparam WAIT_READ = 3;
  localparam WAIT_READ_DONE = 4;
  localparam WAIT_WRITE_DONE = 5;
  localparam READ_DONE = 6;
  localparam WRITE_DONE = 7;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_state <= IDLE;
      wb_ack <= 1'b0;
      wb_data_o <= 32'b0;
      sram_we <= 4'b0000;
      sram_en <= 0;
      wbctrl_mem_op <= 2'b00;
      wbctrl_mem_addr <= 32'b0;
      wbctrl_mem_data <= 32'b0;
      wbctrl_addr_buf <= 32'b0;
      wbctrl_data_buf <= 32'b0;
    end
    else if (finished) begin
      status <= 0;
    end
    else begin
      case (wb_state)
        IDLE: begin // Idle state
          wb_ack <= 1'b0;
          if (wb_cyc_i && wb_stb && !wb_ack) begin
            wbctrl_addr_buf <= wb_addr_i;
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
            wb_data_o <= sram_data_o;
            wbctrl_mem_op <= 2'b00;
            wb_state <= READ_DONE; // Go to read done
          end
        end
        READ_DONE: begin // Read done
          //$display("Read %d from %x (%x)", $signed(wb_data_o), wbctrl_mem_addr, wbctrl_addr_buf);
          wb_ack <= 1'b1;
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
          wb_ack <= 1'b1;
          wb_state <= IDLE; // Return to Idle state
        end
      endcase
    end
  end
  
endmodule
