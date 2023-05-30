module AI_Accelerator_Top #(
  parameter ADDR_OFFSET = 32'h3010_0000
) (
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire [31:0]  wb_addr_i,
  input wire         wb_we_i,
  input wire [31:0]  wb_data_i,
  input wire         wb_stb, // the strobe signal
  output reg         wb_ack, // the readyness signal
  output reg [31:0]  wb_data_o
);
  // Wires for simplifying stuff
  wire [31:0] translated_address;
  wire [31:0] translated_result_address;

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
  reg [31:0] memory_inputs [2*`MEM_SIZE*`MEM_SIZE+5:0];
  // wiring of registers
  wire [32*(2*`MEM_SIZE*`MEM_SIZE+5)-1:0] memory_inputs_unpacked;
  // unpacking
  for (genvar i = 0; i < 2*`MEM_SIZE*`MEM_SIZE+5; i = i + 1) begin
      assign memory_inputs_unpacked[(i*32)+31:(i*32)] = memory_inputs[i];
  end

  // Matrix multiplication result wire
  wire [32*`MEM_SIZE*`MEM_SIZE-1:0] matrix_mult_result_unpacked;
  wire matrix_mult_done; // status wire
  wire [31:0] matrix_mult_result [`MEM_SIZE*`MEM_SIZE:0];
  // unpacking
  for (genvar i = 0; i < `MEM_SIZE*`MEM_SIZE; i = i + 1) begin
      assign matrix_mult_result[i] = matrix_mult_result_unpacked[(i*32)+31:(i*32)];
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

  assign translated_address = wb_addr_i > ADDR_OFFSET ? ((wb_addr_i-ADDR_OFFSET)/4) : 31'b0;
  assign translated_result_address = translated_address > `MEM_SIZE*`MEM_SIZE/4 ? translated_address-`MEM_SIZE*`MEM_SIZE/4 : 31'b0;
  
  always @(posedge wb_clk_i) begin
    last_wb_ack <= wb_ack;
    //$display("%x, %x", operation_reg[5], operation_reg[0]);
    if ( wb_rst_i ) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0; // Disable other modules by default
      wb_data_o <= 32'b0;
      wb_ack <= 1'b0;
      last_wb_ack <= 1'b0;
      for (integer i=0; i < 2*`MEM_SIZE*`MEM_SIZE+6; i = i + 1) begin
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
      wb_ack <= 1'b1;
      if ( translated_address < 2*`MEM_SIZE*`MEM_SIZE+6 )
        memory_inputs[translated_address] <= wb_data_i;
    end
    else if ( !wb_we_i && wb_stb && !busy && memory_inputs[5] != 32'hFFFF_FFFF ) begin // Read operation 
     // $display("Reading from %x, maxmem %x", translated_address, `MEM_SIZE*`MEM_SIZE);
      wb_ack <= 1'b1;
      if ( translated_address < `MEM_SIZE*`MEM_SIZE/4 ) begin
        wb_data_o <= memory_inputs[translated_address];
      end
      else if ( translated_result_address < `MEM_SIZE*`MEM_SIZE ) begin// Matrix C address register address
        //$display("Reading C");
        case (memory_inputs[0])
          32'h0000_0001: begin // matrix multiplication
            //$display("Mul operation");
            if ( matrix_mult_done ) begin
              wb_ack <= 1'b1;
              wb_data_o <= matrix_mult_result[translated_result_address];
            end
          end
          default: begin
            wb_ack <= 1'b1;
            wb_data_o <= 0;
          end
        endcase
      end
      else begin
        wb_data_o <= 0;
      end
    end
    else if ( !wb_we_i && wb_stb && memory_inputs[5] == 32'hFFFF_FFFF && !started ) begin
      case (memory_inputs[0])
        // Enable corresponding module based on operation value in operation register
        32'h0000_0001: begin // matrix multiplication
          if( matrix_mult_done ) begin
            if( busy ) begin
              busy <= 1'b0;
              multiplier_enable <= 1'b0; // Enable matrix multiplication module
              memory_inputs[5] <= 32'h0000_0000;
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
