`define SEQ_LENGTH 512
`define NUM_HEADS 6

module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [31:0]  matrixA_in [`SEQ_LENGTH*`SEQ_LENGTH*`NUM_HEADS-1],
  input wire [31:0]  matrixB_in [0:`SEQ_LENGTH*`NUM_HEADS-1],
  output reg [31:0]  matrixC_out [`SEQ_LENGTH*`SEQ_LENGTH*`NUM_HEADS-1]
);

  // Parameters
  parameter SEQ_LENGTH = `SEQ_LENGTH;
  parameter NUM_HEADS = `NUM_HEADS;
  parameter FP_WIDTH = 32;

  // Internal registers and wires
  reg [31:0] a_idx;
  reg [31:0] b_idx;
  reg [31:0] c_idx;
  reg [FP_WIDTH-1:0] matrixA_reg;
  reg [FP_WIDTH-1:0] matrixB_reg;
  reg [FP_WIDTH-1:0] matrixC_reg;
  reg [2:0] state;
  reg enable_reg;

  // State definition
  localparam IDLE = 3'b000;
  localparam LOAD_MATRIX_A = 3'b001;
  localparam LOAD_MATRIX_B = 3'b010;
  localparam MATRIX_MULT = 3'b011;

  // Assign initial state and enable signal
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      enable_reg <= 0;
    end
    else begin
      state <= enable ? (state == MATRIX_MULT ? IDLE : state + 1) : state;
      enable_reg <= enable;
    end
  end

  // Matrix multiplication logic
  always @(posedge clk) begin
    case (state)
      IDLE:
        // Reset indices and result register
        if (reset) begin
          a_idx <= 0;
          b_idx <= 0;
          c_idx <= 0;
          matrixC_reg <= 0;
        end
      LOAD_MATRIX_A:
        // Load matrixA_reg
        if (enable_reg) begin
          matrixA_reg <= matrixA_in[a_idx];
          a_idx <= a_idx + 1;
        end
      LOAD_MATRIX_B:
        // Load matrixB_reg
        if (enable_reg) begin
          matrixB_reg <= matrixB_in[b_idx];
          b_idx <= b_idx + 1;
        end
      MATRIX_MULT:
        // Perform matrix multiplication
        if (enable_reg) begin
          matrixC_reg <= matrixC_reg + matrixA_reg * matrixB_reg;
          c_idx <= c_idx + 1;
        end
    endcase
  end

  // Output
  always @(posedge clk) begin
    if (reset) begin
      matrixC_out <= 0;
    end
    else begin
      if (enable_reg && state == MATRIX_MULT) begin
        matrixC_out <= matrixC_reg;
      end
    end
  end

endmodule
