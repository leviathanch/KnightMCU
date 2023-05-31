module AI_Accelerator_Top #(
  parameter ADDR_OFFSET = 32'h3010_0000
) (
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire         wb_cyc_i,
  input wire [31:0]  wb_addr_i,
  input wire         wb_we_i,
  input wire [31:0]  wb_data_i,
  input wire         wb_stb, // the strobe signal
  output reg         wb_ack, // the readyness signal
  output wire [31:0]  wb_data_o
);
  // Wires for simplifying stuff
  wire [31:0] translated_address;
  wire [31:0] translated_result_address;
  wire [`TYPE_BW-1:0] datai;
  reg [`TYPE_BW-1:0] datao;
  assign datai = wb_data_i[`TYPE_BW-1:0];
  assign wb_data_o[`TYPE_BW-1:0] = datao;
  assign wb_data_o[31:`TYPE_BW] = 0;

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
  reg [`TYPE_BW-1:0] memory_inputs [`IN_MEM_SIZE-1:0];
  // wiring of registers
  wire [`TYPE_BW*`IN_MEM_SIZE-1:0] memory_inputs_unpacked;
  // unpacking
  for (genvar i = 0; i < `IN_MEM_SIZE; i = i + 1) begin
      assign memory_inputs_unpacked[(i*`TYPE_BW)+`TYPE_BW-1:(i*`TYPE_BW)] = memory_inputs[i];
  end

  // Matrix multiplication result wire
  wire [(`TYPE_BW*`OUT_MEM_SIZE)-1:0] matrix_mult_result_unpacked;
  wire matrix_mult_done; // status wire
  wire [`TYPE_BW-1:0] matrix_mult_result [`OUT_MEM_SIZE-1:0];
  // unpacking
  for (genvar i = 0; i < `OUT_MEM_SIZE; i = i + 1) begin
      assign matrix_mult_result[i] = matrix_mult_result_unpacked[(i*`TYPE_BW)+`TYPE_BW-1:(i*`TYPE_BW)];
  end
 
  // Instantiating modules
  Matrix_Multiplication matrix_mult (
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(multiplier_enable),
    .mem_i(memory_inputs_unpacked),
    .mem_result_o(matrix_mult_result_unpacked),
    .done(matrix_mult_done)
  );

  // State
  reg multiplier_enable;
  reg busy;
  reg started;
  wire strobe;
  reg last_wb_ack; // the readyness signal

  // increments of 1 in C become +4 because int32t = 8bit*4
  assign translated_address = wb_addr_i > ADDR_OFFSET ? ((wb_addr_i-ADDR_OFFSET)/4) : 31'b0;
  // adjust for memory offset
  assign translated_result_address = translated_address > `IN_MEM_SIZE ? translated_address-`IN_MEM_SIZE : 31'b0;
  
  always @(posedge wb_clk_i) begin
    last_wb_ack <= wb_ack;
    //$display("%x, %x", operation_reg[5], operation_reg[0]);
    if ( wb_rst_i ) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0; // Disable other modules by default
      datao <= 32'b0;
      wb_ack <= 1'b0;
      last_wb_ack <= 1'b0;
      for (integer i=0; i < `IN_MEM_SIZE; i = i + 1) begin
        memory_inputs[i] <= 0;
      end
    end
    else if ( wb_ack ) begin
      wb_ack <= 1'b0;
    end
    else if (started) begin
      started <= 1'b0;
    end
    else if ( wb_we_i && wb_stb && !last_wb_ack && !busy ) begin // Write operation
      $display("Writing %d (%b), to %x", $signed(datai), datai, wb_addr_i);
      wb_ack <= 1'b1;
      if ( translated_address < `IN_MEM_SIZE )
        memory_inputs[translated_address] <= datai;
    end
    else if ( !wb_we_i && wb_stb && !busy && memory_inputs[5] != `TYPE_BW'hFFFF_FFFF ) begin // Read operation 
      wb_ack <= 1'b1;
      if ( translated_address < `IN_MEM_SIZE ) begin
        $display("Reading %d (%b), from %x (translated %x)", $signed(memory_inputs[translated_address]), memory_inputs[translated_address], wb_addr_i, translated_address);
        datao <= memory_inputs[translated_address];
      end
      else if ( translated_result_address < `OUT_MEM_SIZE ) begin// Matrix C address register address
        case (memory_inputs[0])
          32'h0000_0001: begin // matrix multiplication
            //$display("Mul operation");
            if ( matrix_mult_done ) begin
              wb_ack <= 1'b1;
              datao <= matrix_mult_result[translated_result_address];
              $display("Reading %d, from %x (translated %x)", $signed(matrix_mult_result[translated_result_address]), wb_addr_i, translated_result_address);
            end
          end
          default: begin
            wb_ack <= 1'b1;
            datao <= 0;
          end
        endcase
      end
      else begin
        datao <= 0;
      end
    end
    else if ( !wb_we_i && wb_stb && memory_inputs[5] == `TYPE_BW'hFFFF_FFFF && !started ) begin
      case (memory_inputs[0])
        // Enable corresponding module based on operation value in operation register
        `TYPE_BW'h1: begin // matrix multiplication
          if( matrix_mult_done ) begin
            if( busy ) begin
              busy <= 1'b0;
              multiplier_enable <= 1'b0; // Enable matrix multiplication module
              memory_inputs[5] <= `TYPE_BW'h9;
            end
            else begin
              wb_ack <= 1'b0; // indicate that we started operation
              busy <= 1'b1; // indicate that we started operation
              multiplier_enable <= 1'b1; // Enable matrix multiplication module
              started <= 1'b1; // fix timing issue
            end
          end
        end
      endcase
    end
  end
  
endmodule
