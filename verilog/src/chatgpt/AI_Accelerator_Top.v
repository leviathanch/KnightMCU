`define SEQ_BITS 14

module AI_Accelerator_Top (
  input wire         clk,
  input wire         reset,
  input wire         wishbone_clk_i,
  input wire         wishbone_rst_i,
  input wire [31:0]  wishbone_addr_i,
  input wire         wishbone_we_i,
  input wire [31:0]  wishbone_data_i,
  output reg [31:0]  wishbone_data_o
);

  // Internal registers to hold matrix values
  reg [31:0] matrixA_in [`SEQ_BITS:0][`SEQ_BITS:0];
  reg [31:0] matrixB_in [`SEQ_BITS:0][`SEQ_BITS:0];
  reg [31:0] matrixC_out [`SEQ_BITS:0][`SEQ_BITS:0];
  
  // Matrix multiplication result wire
  wire [31:0] matrix_mult_result [`SEQ_BITS:0][`SEQ_BITS:0];
  
  // Instantiating modules
  Matrix_Multiplication matrix_mult (
    .clk(clk),
    .reset(reset),
    .enable(multiplier_enable),
    .matrixA_in(matrixA_in),
    .matrixB_in(matrixB_in),
    .matrixC_out(matrix_mult_result)
  );
  
  /* Operation registers:
     0: operation
     1: height A
     2: width A
     3: height B
     4: width B
     7: done writing values, go! 
  */
  reg [31:0] operation_reg [5];

  // State
  reg multiplier_enable;

  // Connecting Wishbone Interface to Registers
  always @(posedge clk) begin
    if (wishbone_clk_i && wishbone_we_i) begin
      if (wishbone_addr_i[31:30] == 4'b00) // Operation register address
        operation_reg[wishbone_addr_i[3:0]] <= wishbone_data_i;
      else if (wishbone_addr_i[31:30] == 4'b01) // Matrix A address register address
        matrixA_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
      else if (wishbone_addr_i[31:30] == 4'b10) // Matrix B address register address
        matrixB_in[wishbone_addr_i[29:`SEQ_BITS+1]][wishbone_addr_i[`SEQ_BITS:0]] <= wishbone_data_i;
    end
  end
  
  // Connecting Wishbone Interface to Controller
  always @(posedge clk) begin
    if (wishbone_clk_i && !wishbone_we_i && operation_reg[3'b111] == 31'h0xff) begin
      // Enable corresponding module based on operation value in operation register
      case (operation_reg[3'b000])
        // Add more cases for different operations as needed
        // Example case for matrix multiplication
        2'b01: begin 
          multiplier_enable <= 1'b1; // Enable matrix multiplication module
        end
        default: begin
          multiplier_enable <= 1'b0; // Disable other modules by default
        end
      endcase
    end
  end
  
endmodule
