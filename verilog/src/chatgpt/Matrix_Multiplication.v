`define SEQ_BITS 14

module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [31:0]  operation_reg [6],
  input wire [31:0]  matrixA_in [`SEQ_BITS:0][`SEQ_BITS:0],
  input wire [31:0]  matrixB_in [`SEQ_BITS:0][`SEQ_BITS:0],
  output reg [31:0]  matrixC_out [`SEQ_BITS:0][`SEQ_BITS:0],
  output reg done
);

  // Internal registers and wires
  reg integer i;
  reg integer j;
  reg integer k;
  reg integer state;

  // State definition
  localparam IDLE = 0;
  localparam LOOP1 = 1;
  localparam LOOP2 = 2;
  localparam LOOP3 = 3;

  /* In C we would do two loops like this:
  for (int i = 0; i < N; i++) {
    for (int j = 0; j < P; j++) {
      matrixC_out[i][j] = 0;  // Initialize the element in the result matrix
      for (int k = 0; k < M; k++) {
        matrixC_out[i][j] += matrixA_in[i][k] * matrixB_in[k][j];
      }
    }
  }
  But that won't work in Verilog, because for loops work differently,
  so we've got to implement this for loop as a state machine instead.
  */
  // Assign initial state
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      done <= 1;
      for (int j=0; j< `SEQ_BITS; j++) begin
        for (int i=0; i< `SEQ_BITS; j++) begin
          matrixC_out[j][i] <= 0;
        end
      end
    end
    else begin
      case (state)
        IDLE:
          if (enable) begin
            // Reset indices and result register
            state <= LOOP1;
            i <= 0;
            j<= 0;
            k <= 0;
            done <= 0;
          end
        LOOP1: begin // for (int i = 0; i < N; i++) {
        end
        LOOP2: begin // for (int j = 0; j < P; j++) {
        end
        LOOP3: begin // or (int k = 0; k < M; k++) {
          matrixC_out[i][j] <= matrixC_out[i][j] + matrixA_in[i][k] * matrixB_in[k][j];
        end
      endcase
    end
  end

endmodule
