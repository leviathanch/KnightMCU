`define SEQ_BITS 14

module AI_Accelerator_Top (
  input wire         wishbone_clk_i,
  input wire         wishbone_rst_i,
  input wire [31:0]  wishbone_addr_i,
  input wire         wishbone_we_i,
  input wire [31:0]  wishbone_data_i,
  input wire         wishbone_stb, // the strobe signal
  output reg         wishbone_ack, // the readyness signal
  output reg [31:0]  wishbone_data_o
);

  // Internal registers to hold matrix values
  reg [31:0] matrixA_in [`SEQ_BITS:0][`SEQ_BITS:0];
  reg [31:0] matrixB_in [`SEQ_BITS:0][`SEQ_BITS:0];
  reg [31:0] matrixC_out [`SEQ_BITS:0][`SEQ_BITS:0];
  
  // Matrix multiplication result wire
  wire [31:0] matrix_mult_result [`SEQ_BITS:0][`SEQ_BITS:0];
  wire matrix_mult_done;
  
  // Instantiating modules
  Matrix_Multiplication matrix_mult (
    .clk(wishbone_clk_i),
    .reset(wishbone_rst_i),
    .enable(multiplier_enable),
    .operation_reg(operation_reg),
    .matrixA_in(matrixA_in),
    .matrixB_in(matrixB_in),
    .matrixC_out(matrix_mult_result),
    .done(matrix_mult_done)
  );
  
  /* Operation registers:
     0: operation
     1: width A
     2: height A
     3: width B
     4: height B
     5: done writing values, go! 
  */
  reg [31:0] operation_reg [6];

  // State
  reg multiplier_enable;
  reg busy;

  
  always @(posedge wishbone_clk_i) begin
    if ( wishbone_rst_i ) begin
      busy <= 1'b0;
      multiplier_enable <= 1'b0; // Disable other modules by default
    end
    else if ( wishbone_we_i && wishbone_stb && !busy ) begin
      // Connecting Wishbone Interface to Registers
      wishbone_ack <= 1'b1;
      if (wishbone_addr_i[31:30] == 4'b00) // Operation register address
        operation_reg[wishbone_addr_i[10:0]] <= wishbone_data_i;
      else if (wishbone_addr_i[31:30] == 4'b01) // Matrix A address register address
        matrixA_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
      else if (wishbone_addr_i[31:30] == 4'b10) // Matrix B address register address
        matrixB_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
    end
    if (!wishbone_we_i && operation_reg[5] == 31'h0xff) begin
      // Connecting Wishbone Interface to Controller
      case (operation_reg[0])
        // Enable corresponding module based on operation value in operation register
        2'b01: begin // matrix multiplication
          if( matrix_mult_done ) begin
            if( !busy ) begin
              wishbone_ack <= 1'b0;
              busy <= 1'b1;
              multiplier_enable <= 1'b1; // Enable matrix multiplication module
            end
            else begin
              busy <= 1'b0; // indicate that we started operation
              multiplier_enable <= 1'b0; // Enable matrix multiplication module
              wishbone_ack <= 1'b0;
              for (int j=0; j< `SEQ_BITS; j++) begin
                for (int i=0; i< `SEQ_BITS; j++) begin
                  matrixC_out[j][i] <= matrix_mult_result[j][i]; // store the result
                end
              end
            end
          end
        end
      endcase
    end
  end
  
endmodule
