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
  reg started;

  always @(posedge wishbone_clk_i) begin
    //$display("%x, %x", operation_reg[5], operation_reg[0]);
    if ( wishbone_rst_i ) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0; // Disable other modules by default
      wishbone_data_o <= 32'b0;
      wishbone_ack <= 1'b0;
      for (int j=0; j< `SEQ_BITS; j++) begin
        for (int i=0; i< `SEQ_BITS; i++) begin
          matrixC_out[j][i] <= 0;
        end
      end
      for (int i=0; i< 5; i++) begin
        operation_reg[i] <= 0;
      end
    end
    else if ( wishbone_ack ) begin
      wishbone_ack <= 1'b0;
    end
    else if ( wishbone_we_i && wishbone_stb && !busy ) begin
      // Connecting Wishbone Interface to Registers
      wishbone_ack <= 1'b1;
      //$display("addr %d, data %d", wishbone_addr_i[31:30], wishbone_data_i);
      if (wishbone_addr_i[31:30] == 2'b00) begin// Operation register address
        operation_reg[wishbone_addr_i[3:0]] <= wishbone_data_i;
      end
      else if (wishbone_addr_i[31:30] == 2'b01) begin // Matrix A address register address
        matrixA_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
      end
      else if (wishbone_addr_i[31:30] == 2'b10) begin// Matrix B address register address
        matrixB_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
      end
    end
    else if ( !wishbone_we_i && wishbone_stb && !busy && operation_reg[5] == 32'h0000_0000 ) begin
      // Connecting Wishbone Interface to Registers
      if( !busy ) begin
        case (operation_reg[0])
          // Enable corresponding module based on operation value in operation register
          32'h0000_0001: begin // matrix multiplication
            if ( matrix_mult_done ) begin
              wishbone_ack <= 1'b1;
              wishbone_data_o <= matrix_mult_result[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]];
            end
          end
          default: begin
            wishbone_ack <= 1'b1;
            wishbone_data_o <= 0;
          end
        endcase
      end
    end
    else if (!wishbone_we_i && wishbone_stb && operation_reg[5] == 32'hFFFF_FFFF && !started ) begin
      // Connecting Wishbone Interface to Controller
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
              wishbone_ack <= 1'b0; // indicate that we started operation
              busy <= 1'b1; // indicate that we started operation
              multiplier_enable <= 1'b1; // Enable matrix multiplication module
              started <= 1'b1; // fix timing issue
            end
          end
        end
      endcase
    end
    else if (started) begin
      started <= 1'b0;
    end
  end
  
endmodule
