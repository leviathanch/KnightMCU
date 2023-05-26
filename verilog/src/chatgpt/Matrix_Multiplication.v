`define SEQ_BITS 14

module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [31:0]  operation_reg [6],
  input wire [31:0]  matrixA_in [0:`SEQ_BITS][0:`SEQ_BITS],
  input wire [31:0]  matrixB_in [0:`SEQ_BITS][0:`SEQ_BITS],
  output reg [31:0]  matrixC_out [0:`SEQ_BITS][0:`SEQ_BITS],
  output reg         done
);

  // Internal registers and wires
  reg integer i;
  reg integer j;
  reg integer k;
  reg integer N; // width A
  reg integer M; // height A
  reg integer P; // height B
  reg integer state;

  // State definition
  localparam IDLE = 0;
  localparam LOOP1 = 1;
  localparam LOOP2 = 2;
  localparam LOOP3 = 3;
  localparam FSM_DONE = 4;

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
      M <= 0;
      N <= 0;
      P <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      done <= 1'b1;
      for (i=0; i<= `SEQ_BITS; i=i+1) begin
        for (j=0; j<= `SEQ_BITS; j=j+1) begin
          matrixC_out[i][j] <= 0;
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
            j <= 0;
            k <= 0;
            done <= 0;
            /* Operation registers:
               0: operation
               1: width A
               2: height A
               3: width B
               4: height B
               5: done writing values, go!
            */
            N <= operation_reg[1]; // width A
            M <= operation_reg[2]; // height A
            P <= operation_reg[4]; // height B
          end
        LOOP1: begin // for (int i = 0; i < N; i++) {
          if (i < N) begin
            state <= LOOP2;
          end
          else begin
            state <= FSM_DONE;
          end
        end
        LOOP2: begin // for (int j = 0; j < P; j++) {
          if (j < P) begin
            state <= LOOP3;
          end
          else begin
            state <= LOOP1;
            i <= i + 1;
            j <= 0;
          end
        end
        LOOP3: begin // for (int k = 0; k < M; k++) {
          matrixC_out[i][j] <= matrixC_out[i][j] + matrixA_in[i][k] * matrixB_in[k][j];
          //$display("matrixC_out[%d][%d] = %d", i, j, matrixC_out[i][j]);
          if (k < M - 1) begin
            state <= LOOP3;
            k <= k + 1;
          end
          else begin
            state <= LOOP2;
            j <= j + 1;
            k <= 0;
          end
        end
        FSM_DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
