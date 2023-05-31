module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [(32*`IN_MEM_SIZE)-1:0] mem_i,
  output wire [(32*`OUT_MEM_SIZE)-1:0] mem_result_o,
  output reg         done
);
  // packing inputs:
  wire [31:0] memory_inputs [`IN_MEM_SIZE-1:0];
  for (genvar i = 0; i < `IN_MEM_SIZE; i = i + 1) begin // packing inputs
    assign memory_inputs[i] = mem_i[i*32+31:i*32];
  end

  // unpacking outputs
  reg [31:0] mem_result [`OUT_MEM_SIZE-1:0];
  for (genvar i = 0; i < `OUT_MEM_SIZE; i = i + 1) begin // unpacking results
    assign mem_result_o[i*32+31:i*32] = mem_result[i];
  end

  // FSM variables
  reg integer i;
  reg integer j;
  reg integer k;
  reg integer state;

  // Dynamic address calculation
  reg integer wa; // width A
  reg integer ha; // height A
  reg integer wb; // width B
  reg integer hb; // height B

  wire [31:0] base_addr_a;
  wire [31:0] base_addr_b;
  wire [31:0] base_addr_c;
  assign base_addr_a = 32'h0000_0006;
  assign base_addr_b = base_addr_a + wa*ha;

  // State definition
  localparam IDLE = 0;
  localparam LOOP1 = 1;
  localparam LOOP2 = 2;
  localparam LOOP3 = 3;
  localparam FSM_DONE = 4;

  /* In C we would do two loops like this:
  for (int i = 0; i < wa; i++) {
    for (int j = 0; j < hb; j++) {
      matrixC_out[i][j] = 0;  // Initialize the element in the result matrix
      for (int k = 0; k < ha; k++) {
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
      // reset dimensions
      wa <= 0;
      ha <= 0;
      wb <= 0;
      hb <= 0;
      // reset FSM
      state <= IDLE;
      i <= 0;
      j <= 0;
      k <= 0;
      done <= 1'b1; // go into ready state
      // reset result register
      for (integer i = 0; i < `OUT_MEM_SIZE; i = i + 1) begin
        mem_result[i] <= 0;
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
          // values for calculating base addresses
          wa <= memory_inputs[1]; // width A
          ha <= memory_inputs[2]; // height A
          wb <= memory_inputs[3]; // width B
          hb <= memory_inputs[4]; // height B
          
          for (integer i = 0; i < `OUT_MEM_SIZE; i = i + 1) begin
            mem_result[i] <= 0;
          end
        end
        LOOP1: begin // for (int i = 0; i < wa; i++) {
          if (i < wa) begin
            state <= LOOP2;
          end
          else begin
            state <= FSM_DONE;
          end
        end
        LOOP2: begin // for (int j = 0; j < hb; j++) {
          if (j < hb) begin
            state <= LOOP3;
          end
          else begin
            state <= LOOP1;
            i <= i + `PARALLEL_MULT_JOBS; // parallelism
            //i <= i + 1;
            j <= 0;
          end
        end
        LOOP3: begin // for (int k = 0; k < ha; k++) {
          //mem_result[i*hb+j] <= mem_result[i*hb+j] + memory_inputs[base_addr_a+i*wa+k] * memory_inputs[base_addr_b+k*wb+j];
          for(integer g = 0; g < `PARALLEL_MULT_JOBS; g = g +1 ) begin
            //matrixC_out[i+g][j] <= matrixC_out[i+g][j] + matrixA_in[i+g][k] * matrixB_in[k][j]; // parallelism
            mem_result[(i+g)*hb+j] <= mem_result[(i+g)*hb+j] + memory_inputs[base_addr_a+(i+g)*wa+k] * memory_inputs[base_addr_b+k*wb+j];
          end
          if (k < ha - 1) begin
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
