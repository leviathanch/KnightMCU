module Convolution #(parameter num_fpus = 4) (
  input wire clk,
  input wire reset,
  input [7:0] len1,                       // length of x1
  input [7:0] len2,                       // length of x2
  input [255:0][63:0] x1,                 // matrix
  input [255:0][63:0] x2,                 // kernel
  output reg [255:0][63:0] y              // convoluted matrix
); 
  reg [7:0] curr_row;                      // Current row being processed
  reg [7:0] curr_col;                      // Current column being processed
  reg [7:0] fpu_count;                      // Counter for managing FPUs
  reg [255:0][63:0] partial_results[num_fpus];  // Partial results from each FPU
  reg [num_fpus] fpus_idle;            // State of each FPU (0 - Busy, 1 - Idle)

  // Declare input and output buffers for each FPU
  reg [255:0][63:0] input_buffers[num_fpus];
  reg [255:0][63:0] output_buffers[num_fpus];

  reg [num_fpus][63:0] opa;
  reg [num_fpus][63:0] opb;
  wire [num_fpus][63:0] fpu_out;
  reg [num_fpus][1:0]rmode;
  reg [num_fpus][2:0]fpu_op;
  wire [num_fpus] ready;

  // FSM states
  reg [num_fpus][255:0] state;
  parameter IDLE = 0;
  parameter LOAD_INPUT = 1;
  parameter FPU_MULT = 2;
  parameter FPU_MULT_WAIT = 3;
  parameter FPU_MULT_FETCH = 4;
  parameter FPU_ADD = 5;
  parameter FPU_ADD_WAIT = 6;
  parameter FPU_ADD_FETCH = 7;
  integer i;

  for (genvar i = 0; i < num_fpus; i = i + 1) begin
    fpu fpu_inst(
      .clk(clk),
      .rst(reset),
      .enable(~fpus_idle[i]),  // Enable FPU if it's not idle
      .rmode(rmode[i]),           // Set rounding mode (modify as needed)
      .fpu_op(fpu_op[i]),          // Set FPU operation (modify as needed)
      .opa(opa[i]),
      .opb(opb[i]),
      .out(fpu_out[i]),
      .ready(ready[i]),
      .underflow(),
      .overflow(),
      .inexact(),
      .exception(),
      .invalid()
    );
  end

  always @(posedge clk, negedge reset) begin
    if (!reset) begin
      y <= 0;                    // Reset the output register
      curr_row <= 0;             // Reset the current row
      curr_col <= 0;             // Reset the current column
      fpu_count <= 0;            // Reset the FPU counter
      for (i = 0; i < num_fpus; i = i + 1) begin
        partial_results[i] <= 0;      // Reset the partial results
      end
      fpus_idle <= 1;            // Set all FPUs to idle state
      state <= IDLE;             // Initial state
    end else begin
      for (i = 0; i < num_fpus; i = i + 1) begin
        case (state[i])
          IDLE: begin
            if (curr_row[i] < len1) begin
              state[i] <= LOAD_INPUT;
            end
          end
          LOAD_INPUT: begin
            // Load input buffers for active FPUs
            //if (curr_col == 0)
            //  input_buffers[i] <= x1[curr_row + i*256 : curr_row + i*256 + 255];
            state[i] <= FPU_MULT;
          end
          /* originally we did:
          for (i = 0; i < N-M; i = i + 1) begin : ADDER_BLOCK
            temp[i] <= $realtobits(0);
            for (k = 0; k < M; k = k + 1) begin
              temp_real = $bitstoreal(temp[i]) + $bitstoreal(x1[i + k]) * $bitstoreal(x2[k]);
              temp[i] <= $realtobits(temp_real);
            end
          end
          */
          FPU_MULT: begin
            // load x1[i+k] into opa
            // load x2[k] into opb
            // set operation multiply
            // enable operation
          end
          FPU_MULT_WAIT: begin
            // wait for operation being done
          end
          FPU_MULT_FETCH: begin
            // fetch data into buffer
            // reset
          end
          FPU_ADD: begin
            // load buffer1 into opa
            // load buffer2 into opb
            // set operation addition
            // enable operation
          end
          FPU_ADD_WAIT: begin
            // wait for operation being done
          end
          FPU_ADD_FETCH: begin
          end
          ACCUMULATE_RESULTS: begin
          end
        endcase
      end
    end
  end
endmodule
