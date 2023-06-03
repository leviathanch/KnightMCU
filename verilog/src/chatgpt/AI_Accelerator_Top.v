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
  reg [`KICP_SRAM_COLS+1:0] sram_addr;
  reg [31:0] sram_data_i;
  wire [31:0] sram_data_o;

  RAM256 #(`KICP_SRAM_COLS) sram (
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
      case ( operation ) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          case (mmul_mem_op)
            2'b01: begin // Read
              sram_en <= 1;
              sram_addr <= mmul_addr_o[`KICP_SRAM_COLS+1:0];
              mem_read_wait <= 1;
            end
            2'b11: begin // Write
              sram_we <= 4'b1111;
              sram_en <= 1;
              sram_addr <= mmul_addr_o[`KICP_SRAM_COLS+1:0];
              sram_data_i <= mmul_data_o;
              mem_write_wait <= 1;
            end
          endcase
        end
        `TYPE_BW'h2: begin // matrix convolution
          case (mconv_mem_op)
            2'b01: begin // Read
              sram_en <= 1;
              sram_addr <= mconv_addr_o[`KICP_SRAM_COLS+1:0];
              mem_read_wait <= 1;
            end
            2'b11: begin // Write
              sram_we <= 4'b1111;
              sram_en <= 1;
              sram_addr <= mconv_addr_o[`KICP_SRAM_COLS+1:0];
              sram_data_i <= mconv_data_o;
              mem_write_wait <= 1;
            end
          endcase
        end
      endcase
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
  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0;
      convolution_enable <= 1'b0;
    end
    else if ( started && busy ) begin
      started <= 1'b0;
    end
    else begin
      case ( operation ) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          if( matrix_mult_done && busy ) begin
            busy <= 1'b0;
            multiplier_enable <= 1'b0; // Enable matrix multiplication module
            status <= `TYPE_BW'h0; // Done
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
            status <= `TYPE_BW'h0; // Done
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
  reg read_wait_cycle;
  reg write_wait_cycle;
  reg [1:0] wb_state;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_state <= 2'b00;
      wb_ack <= 1'b0;
      wb_data_o <= 32'b0;
      read_wait_cycle <= 0;
      write_wait_cycle <= 0;
      sram_we <= 4'b0000;
      sram_en <= 0;
    end
    else if (read_wait_cycle) begin
      if( sram_addr != sram_data_o ) begin
        read_wait_cycle <= 0;
        sram_en <= 0;
        wb_data_o <= sram_data_o;
      end
    end
    else if (write_wait_cycle) begin
      if( sram_data_i == sram_data_o ) begin
        sram_we <= 4'b0000;
        sram_en <= 0;
        write_wait_cycle <= 0;
      end
    end
    else begin
      case (wb_state)
        2'b00: begin // Idle state
          if ( busy ) begin
            wb_ack <= 1'b0;
          end
          else if (wb_cyc_i && wb_stb && !wb_ack) begin
            wb_ack <= 1'b1;
            if (wb_we_i) begin
              wb_data_o <= 32'h0000_0000;
              wb_state <= 2'b01; // Write state
            end else begin
              // increments of 1 become 4 because 32 int32_t = 4 bytes:
              if((wb_addr_i-ADDR_OFFSET)/4 == 32'h0) begin
                wb_data_o <= operation;
              end
              else if((wb_addr_i-ADDR_OFFSET)/4 == 32'h1 ) begin
                wb_data_o <= status;
              end
              else begin
                read_wait_cycle <= 1;
                sram_en <= 1;
                sram_addr <= wb_addr_i[`KICP_SRAM_COLS+1:0]/4-2;
              end
              wb_state <= 2'b10; // Read state
            end
          end
        end

        2'b01: begin // Write state
          if (!wb_cyc_i) begin
            wb_ack <= 1'b0;
            wb_state <= 2'b00; // Return to Idle state
          end else if (!wb_stb) begin
            wb_ack <= 1'b0;
          end else if (wb_we_i) begin
            // increments of 1 become 4 because 32 int32_t = 4 bytes:
            if((wb_addr_i-ADDR_OFFSET)/4 == 32'h0 ) begin
              operation <= wb_data_i;
            end
            else if((wb_addr_i-ADDR_OFFSET)/4 == 32'h1 ) begin
              status <= wb_data_i;
            end
            else begin
              sram_we <= 4'b1111;
              sram_en <= 1;
              write_wait_cycle <= 1;
              sram_addr <= wb_addr_i[`KICP_SRAM_COLS+1:0]/4-2;
              sram_data_i <= wb_data_i; //[`TYPE_BW-1:0];
            end
            wb_ack <= 1'b1;
          end
        end

        2'b10: begin // Read state
          if (!wb_cyc_i) begin
            wb_ack <= 1'b0;
            wb_state <= 2'b00; // Return to Idle state
          end else if (!wb_stb) begin
            wb_ack <= 1'b0;
          end
        end

      endcase
    end
  end
  
endmodule
