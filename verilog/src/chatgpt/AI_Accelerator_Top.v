module AI_Accelerator_Top (
  input wire         wb_clk_i,
  input wire         wb_rst_i,
  input wire [31:0]  wb_addr_i,
  input wire         wb_we_i,
  input wire [31:0]  wb_data_i,
  input wire         wb_stb, // the strobe signal
  output reg         wb_ack, // the readyness signal
  output reg [31:0]  wb_data_o
);
  /* Operation registers:
     0: operation
     1: width A
     2: height A
     3: width B
     4: height B
     5: done writing values, go!
  */
  reg [31:0] operation_reg [6:0];
  wire [6*32-1:0] operation_reg_port;

  // Wires for simplifying stuff
  wire [1:0] prefix;
  wire [14:0] mi;
  wire [14:0] mj;

  // making iverilog stop complain
  wire [32*`MEM_SIZE*`MEM_SIZE-1:0] matrixA_port;
  wire [32*`MEM_SIZE*`MEM_SIZE-1:0] matrixB_port;

  // registers holding values
  reg [31:0] matrixA_in [`MEM_SIZE:0][`MEM_SIZE:0];
  reg [31:0] matrixB_in [`MEM_SIZE:0][`MEM_SIZE:0];

  // Matrix multiplication result wire
  wire [31:0] matrix_mult_result [`MEM_SIZE:0][`MEM_SIZE:0];
  wire [32*`MEM_SIZE*`MEM_SIZE-1:0] matrix_mult_result_port;
  wire matrix_mult_done;

  // wiring of registers
  for (genvar i = 0; i < `MEM_SIZE; i = i + 1) begin
    for (genvar j = 0; j < `MEM_SIZE; j = j + 1) begin
      assign matrixA_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32] = matrixA_in[i][j];
      assign matrixB_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32] = matrixB_in[i][j];
      assign matrix_mult_result[i][j] = matrix_mult_result_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32];
    end
  end
  for (genvar i = 0; i < 6; i = i + 1) begin
    assign operation_reg_port[i*32+31:i*32] = operation_reg[i];
  end
  
  // Instantiating modules
  Matrix_Multiplication matrix_mult (
    .clk(wb_clk_i),
    .reset(wb_rst_i),
    .enable(multiplier_enable),
    .operation_reg_port(operation_reg_port),
    .matrixA_in_port(matrixA_port),
    .matrixB_in_port(matrixB_port),
    .matrixC_out_port(matrix_mult_result_port),
    .done(matrix_mult_done)
  );

  // State
  reg multiplier_enable;
  reg busy;
  reg started;
  wire strobe;
  
  always @(posedge wb_clk_i) begin
    //$display("%x, %x", operation_reg[5], operation_reg[0]);
    if ( wb_rst_i ) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0; // Disable other modules by default
      wb_data_o <= 32'b0;
      wb_ack <= 1'b0;
      for (integer i=0; i < 6; i++) begin
        operation_reg[i] <= 0;
      end
      for (integer i=0; i < `MEM_SIZE; i = i + 1) begin
        for (integer j = 0; j < `MEM_SIZE; j = j + 1) begin
          matrixA_in[i][j] <= 0;
          matrixB_in[i][j] <= 0;
        end
      end
    end
    else if ( wb_ack ) begin
      wb_ack <= 1'b0;
    end
    else if (started) begin
      started <= 1'b0;
    end
    else if ( wb_we_i && wb_stb && !busy ) begin
      if (prefix == 2'b00) begin// Operation register address
        wb_ack <= 1'b1;
        operation_reg[wb_addr_i[3:0]] <= wb_data_i;
      end
      else if (prefix == 2'b01) begin // Matrix A address register address
        wb_ack <= 1'b1;
        matrixA_in[mi][mj] <= wb_data_i;
      end
      else if (prefix == 2'b10) begin// Matrix B address register address
        wb_ack <= 1'b1;
        matrixB_in[mi][mj] <= wb_data_i;
      end
    end
    else if ( !wb_we_i && wb_stb && !busy && operation_reg[5] != 32'hFFFF_FFFF ) begin // Read operation
      if (prefix == 2'b00) begin// Operation register address
        wb_ack <= 1'b1;
        if (wb_addr_i[2:0]<7)
          wb_data_o <= operation_reg[wb_addr_i[2:0]];
        else
          wb_data_o <= 0;
      end
      else if (prefix == 2'b01) begin // Matrix A address register address
        wb_ack <= 1'b1;
        if (mi<`MEM_SIZE && mj<`MEM_SIZE)
          wb_data_o <= matrixA_in[mi][mj];
        else
          wb_data_o <= 0;
      end
      else if (prefix == 2'b10) begin// Matrix B address register address
        wb_ack <= 1'b1;
        if (mi<`MEM_SIZE && mj<`MEM_SIZE)
          wb_data_o <= matrixB_in[mi][mj];
        else
          wb_data_o <= 0;
      end
      else if (prefix == 2'b11) begin// Matrix C address register address
        case (operation_reg[0])
          // Enable corresponding module based on operation value in operation register
          32'h0000_0001: begin // matrix multiplication
            if ( matrix_mult_done ) begin
              wb_ack <= 1'b1;
              $display("%d, %d", mi, mj);
              if (mi<`MEM_SIZE && mj<`MEM_SIZE)
                wb_data_o <= matrix_mult_result[mi][mj];
              else
                wb_data_o <= 0;
            end
          end
          default: begin
            wb_ack <= 1'b1;
            wb_data_o <= 0;
          end
        endcase
      end
    end
    else if ( !wb_we_i && wb_stb && operation_reg[5] == 32'hFFFF_FFFF && !started ) begin
      case (operation_reg[0])
        // Enable corresponding module based on operation value in operation register
        32'h0000_0001: begin // matrix multiplication
          if( matrix_mult_done ) begin
            if( busy ) begin
              busy <= 1'b0;
              multiplier_enable <= 1'b0; // Enable matrix multiplication module
              operation_reg[5] <= 32'h0000_0000;
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

  assign mj = wb_addr_i[`SEQ_BITS:0];
  assign mi = wb_addr_i[`SEQ_BITS+`SEQ_BITS:`SEQ_BITS+1];
  assign prefix = wb_addr_i[23:22];
  
endmodule
