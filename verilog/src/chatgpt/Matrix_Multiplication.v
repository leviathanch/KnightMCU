module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [32*6-1:0]  operation_reg_port,
  input wire [32*`MEM_SIZE*`MEM_SIZE-1:0]  matrixA_in_port,
  input wire [32*`MEM_SIZE*`MEM_SIZE-1:0]  matrixB_in_port,
  output wire [32*`MEM_SIZE*`MEM_SIZE-1:0]  matrixC_out_port,
  output reg         done
);

  wire [31:0]  operation_reg [6:0];
  wire [31:0]  matrixA_in [`MEM_SIZE:0][`MEM_SIZE:0];
  wire [31:0]  matrixB_in [`MEM_SIZE:0][`MEM_SIZE:0];
  reg [31:0]  matrixC_out [`MEM_SIZE:0][`MEM_SIZE:0];

  // wiring of registers
  for (genvar i = 0; i < `MEM_SIZE; i = i + 1) begin
    for (genvar j = 0; j < `MEM_SIZE; j = j + 1) begin
      assign matrixA_in[i][j] = matrixA_in_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32];
      assign matrixB_in[i][j] = matrixB_in_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32];
      assign matrixC_out_port[((i*`MEM_SIZE)+j)*32+31:((i*`MEM_SIZE)+j)*32] = matrixC_out[i][j];
    end
  end
  for (genvar i = 0; i < 6; i = i + 1) begin
    assign operation_reg[i] = operation_reg_port[i*32+31:i*32];
  end

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

  // Turning the thing on
  always @(posedge enable) begin
    state <= IDLE;
  end

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
      for (integer i = 0; i < `MEM_SIZE; i = i + 1) begin
        for (integer j = 0; j < `MEM_SIZE; j = j + 1) begin
          matrixC_out[i][j] <= 0;  // Initialize the element in the result matrix
        end
      end
    end
    else if (enable) begin
      case (state)
        IDLE: begin
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
          for (integer i = 0; i < `MEM_SIZE; i = i + 1) begin
            for (integer j = 0; j < `MEM_SIZE; j = j + 1) begin
              matrixC_out[i][j] <= 0;  // Initialize the element in the result matrix
            end
          end
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
            i <= i + `PARALLEL_MULT_JOBS; // Parallelism
            j <= 0;
          end
        end
        LOOP3: begin // for (int k = 0; k < M; k++) {
          for(integer g = 0; g < `PARALLEL_MULT_JOBS; g = g +1 ) begin
            matrixC_out[i+g][j] <= matrixC_out[i+g][j] + matrixA_in[i+g][k] * matrixB_in[k][j]; // Parallelism
          end
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
        end
      endcase
    end
  end
endmodule
