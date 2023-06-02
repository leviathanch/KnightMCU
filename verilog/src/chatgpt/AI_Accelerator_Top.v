module AI_Accelerator_Top #(
  parameter ADDR_OFFSET = 32'h3000_0000
) (
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire         wb_stb, // the strobe signal
  input wire         wb_cyc_i,
  input wire         wb_we_i,
  input wire [3:0]   wbs_sel_i,
  input wire [31:0]  wb_addr_i,
  input wire [31:0]  wb_data_i,
  output reg         wb_ack, // the readyness signal
  output reg [31:0]  wb_data_o
);
  
  // Parallelism
  reg [31:0] p;

  /* SRAM:
     0: operation code to perform
     // 1..4: dimensional information
     1: width A
     2: height A
     3: width B
     4: height B
     // shoot and go
     5: done writing values, go!
     // rest of space is the input data
     6+*: The matrices
  */
  reg [`TYPE_BW-1:0] DFFRAM [`DFF_MEM_SIZE-1:0]; // the memory
  
  /*
    Memory controller
  */
  reg mem_opdone;
  reg next_mem_opdone;
  reg [1:0] mem_ctl_state;

  always @(posedge wb_clk_i) begin
    mem_opdone <= next_mem_opdone;
    if (wb_rst_i) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0;
      mmul_data_i <= 0;
      mem_opdone <= 0;
      next_mem_opdone <= 0;
    end
    else if ( mem_opdone ) begin
      mem_opdone <= 0;
      next_mem_opdone <= 0;
    end
    else if (! mem_opdone )begin
      case ( DFFRAM[0] ) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          case (mmul_mem_op)
            2'b01: begin // Read
              mmul_data_i <= DFFRAM[mmul_addr_o];
              next_mem_opdone <= 1;
            end
            2'b11: begin // Write
              DFFRAM[mmul_addr_o] <= mmul_data_o;
              mmul_data_i <= 0;
              next_mem_opdone <= 1;
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
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(multiplier_enable),
    .done(matrix_mult_done),
    .addr_o(mmul_addr_o),
    .data_i(mmul_data_i),
    .data_o(mmul_data_o),
    .mem_opdone(mem_opdone),
    .mem_operation(mmul_mem_op)
  );
  // Matrix multiplication result wire
  reg multiplier_enable; // on switch
  wire matrix_mult_done; // status wire
  reg [`TYPE_BW-1:0] mmul_data_i;
  wire [`TYPE_BW-1:0] mmul_data_o;
  wire [31:0] mmul_addr_o;
  wire [1:0] mmul_mem_op; // Read 01 /Write 11 /None 00

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
    end
    else if ( started ) begin
      started <= 1'b0;
    end
    else begin
      case (DFFRAM[0]) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          if( matrix_mult_done && busy ) begin
            busy <= 1'b0;
            multiplier_enable <= 1'b0; // Enable matrix multiplication module
            DFFRAM[5] <= `TYPE_BW'h0; // Done
          end
          else if ( DFFRAM[5] == `TYPE_BW'hffff_ffff ) begin
            busy <= 1'b1; // indicate that we started operation
            multiplier_enable <= 1'b1; // Enable matrix multiplication module
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
  reg [1:0] wb_state;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_state <= 2'b00;
      wb_ack <= 1'b0;
      wb_data_o <= 32'b0;
      for (p = 0; p < `DFF_MEM_SIZE; p = p + 1) begin
        DFFRAM[p] <= 0;
      end
    end
    else begin
      case (wb_state)
        2'b00: begin // Idle state
          if ( busy ) begin
            wb_ack <= 1'b0;
          end
          else if (wb_cyc_i && wb_stb && !wb_ack) begin
            if (wb_addr_i >= ADDR_OFFSET && wb_addr_i < ADDR_OFFSET + 4*`DFF_MEM_SIZE) begin
              wb_ack <= 1'b1;
              if (wb_we_i) begin
                wb_data_o <= 32'h0000_0000;
                wb_state <= 2'b01; // Write state
              end else begin
                // increments of 1 become 4 because 32 int32_t = 4 bytes:
                wb_data_o <= DFFRAM[(wb_addr_i-ADDR_OFFSET)/4];
                wb_state <= 2'b10; // Read state
              end
            end
            else begin
              wb_ack <= 1'b0;
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
            DFFRAM[(wb_addr_i-ADDR_OFFSET)/4] <= wb_data_i; //[`TYPE_BW-1:0];
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



