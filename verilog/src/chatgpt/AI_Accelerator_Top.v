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

  // Genvar
  genvar g;
  
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
  reg [`TYPE_BW-1:0] memory_inputs [`IN_MEM_SIZE-1:0]; // the memory
  // wiring of registers
  wire [`TYPE_BW*`IN_MEM_SIZE-1:0] memory_inputs_unpacked;
  // unpacking
  for (g = 0; g < `IN_MEM_SIZE; g = g + 1) begin
      assign memory_inputs_unpacked[(g*`TYPE_BW)+`TYPE_BW-1:(g*`TYPE_BW)] = memory_inputs[g];
  end

  /*
    All the modules go here:
  */
  
  // Matrix multiplication
  Matrix_Multiplication matrix_mult (
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(multiplier_enable),
    .mem_i(memory_inputs_unpacked),
    .mem_result_o(matrix_mult_result_unpacked),
    .done(matrix_mult_done)
  );
  // Matrix multiplication result wire
  reg multiplier_enable; // on switch
  wire matrix_mult_done; // status wire
  // the memory:
  wire [(`TYPE_BW*`OUT_MEM_SIZE)-1:0] matrix_mult_result_unpacked;
  wire [`TYPE_BW-1:0] matrix_mult_result [`OUT_MEM_SIZE-1:0];
  // unpacking
  for (g = 0; g < `OUT_MEM_SIZE; g = g + 1) begin
    assign matrix_mult_result[g] = matrix_mult_result_unpacked[(g*`TYPE_BW)+`TYPE_BW-1:(g*`TYPE_BW)];
  end

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
      case (memory_inputs[0]) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          if( matrix_mult_done ) begin
            if( busy ) begin
              busy <= 1'b0;
              multiplier_enable <= 1'b0; // Enable matrix multiplication module
              memory_inputs[5] <= `TYPE_BW'h0; // Done
            end
            else if ( memory_inputs[5] == `TYPE_BW'hffff_ffff ) begin
              busy <= 1'b1; // indicate that we started operation
              multiplier_enable <= 1'b1; // Enable matrix multiplication module
              started <= 1'b1;
            end
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
      for (p = 0; p < `IN_MEM_SIZE; p = p + 1) begin
        memory_inputs[p] <= 0;
      end
    end
    else begin
      case (wb_state)
        2'b00: begin // Idle state
          if ( busy) begin
            wb_ack <= 1'b0;
          end
          else if (wb_cyc_i && wb_stb && !wb_ack) begin
            if (wb_addr_i >= ADDR_OFFSET && wb_addr_i < ADDR_OFFSET + 4*`IN_MEM_SIZE) begin
              wb_ack <= 1'b1;
              if (wb_we_i) begin
                wb_data_o <= 32'h0000_0000;
                wb_state <= 2'b01; // Write state
              end else begin
                // increments of 1 become 4 because 32 int32_t = 4 bytes:
                wb_data_o <= memory_inputs[(wb_addr_i-ADDR_OFFSET)/4];
                wb_state <= 2'b10; // Read state
              end
            end
            else if ( wb_addr_i >= ADDR_OFFSET + 4*`IN_MEM_SIZE && wb_addr_i < ADDR_OFFSET + 4*(`IN_MEM_SIZE+`OUT_MEM_SIZE) ) begin// Matrix C address register address
              wb_ack <= 1'b1;
              case (memory_inputs[0])
                `TYPE_BW'h0000_0001: begin // matrix multiplication
                  // increments of 1 become 4 because 32 int32_t = 4 bytes:
                  wb_data_o <= matrix_mult_result[(wb_addr_i-ADDR_OFFSET)/4-`IN_MEM_SIZE];
                  wb_state <= 2'b10; // Read state
                end
                default: begin
                  wb_data_o <= 0;
                  wb_state <= 2'b10; // Read state
                end
              endcase
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
            memory_inputs[(wb_addr_i-ADDR_OFFSET)/4] <= wb_data_i; //[`TYPE_BW-1:0];
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



