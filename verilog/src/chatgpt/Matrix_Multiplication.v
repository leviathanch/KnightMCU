module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire [`TYPE_BW-1:0] data_i,
  output reg [`TYPE_BW-1:0] data_o,
  output reg [31:0] addr_o,
  input wire [(`TYPE_BW*`IN_MEM_SIZE)-1:0] mem_i,
  output wire [(`TYPE_BW*`OUT_MEM_SIZE)-1:0] mem_result_o,
  output reg         done
);
  // Genvar
  genvar g;

  // Parallelism
  reg [31:0] p;

  // packing inputs:
  wire [`TYPE_BW-1:0] memory_inputs [`IN_MEM_SIZE-1:0];
  for (g = 0; g < `IN_MEM_SIZE; g = g + 1) begin // packing inputs
    assign memory_inputs[g] = mem_i[(g*`TYPE_BW)+`TYPE_BW-1:g*`TYPE_BW];
  end

  // unpacking outputs
  reg [`TYPE_BW-1:0] mem_result [`OUT_MEM_SIZE-1:0];
  for (g = 0; g < `OUT_MEM_SIZE; g = g + 1) begin // unpacking results
    assign mem_result_o[(g*`TYPE_BW)+`TYPE_BW-1:g*`TYPE_BW] = mem_result[g];
  end
  
  // FSM variables
  reg [31:0] i;
  reg [31:0] j;
  reg [31:0] k;
  reg [31:0] state;

  // Dynamic address calculation
  reg [31:0] wa; // width A
  reg [31:0] ha; // height A
  reg [31:0] wb; // width B
  reg [31:0] hb; // height B

  wire [31:0] base_addr_a;
  wire [31:0] base_addr_b;
  wire [31:0] base_addr_c;
  assign base_addr_a = 32'h0000_0006;
  assign base_addr_b = base_addr_a + wa*ha;
  assign base_addr_c = base_addr_a + wa*ha + wb*hb;

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
      for (p = 0; p < `OUT_MEM_SIZE; p = p + 1) begin
        mem_result[p] <= 0;
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
          for (p = 0; p < `OUT_MEM_SIZE; p = p + 1) begin
            mem_result[p] <= 0;
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
            j <= 0;
          end
        end
        LOOP3: begin // for (int k = 0; k < ha; k++) {
          for(p = 0; p < `PARALLEL_MULT_JOBS; p = p +1 ) begin
            mem_result[(i+p)*hb+j] <= mem_result[(i+p)*hb+j] + memory_inputs[base_addr_a+(i+p)*wa+k] * memory_inputs[base_addr_b+k*wb+j];
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
