module Matrix_Multiplication (
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire         mem_opdone,
  input wire [`TYPE_BW-1:0] data_i,
  output reg [`TYPE_BW-1:0] data_o,
  output reg [31:0]  addr_o,
  output reg [1:0]   mem_operation, // Read 01 /Write 11 /None 00
  output reg         done
);
  // FSM variables
  reg [31:0] i;
  reg [31:0] j;
  reg [31:0] k;
  reg [31:0] state;

  // Dynamic address calculation
  reg [31:0] height_a; // width A
  reg [31:0] width_a; // height A
  reg [31:0] height_b; // width B
  reg [31:0] width_b; // height B

  wire [31:0] base_addr_a;
  wire [31:0] base_addr_b;
  wire [31:0] base_addr_c;

  assign base_addr_a = 32'h0000_0006; // 6 parameters
  assign base_addr_b = base_addr_a + height_a*width_a;
  assign base_addr_c = base_addr_b + height_a*width_a + height_b*width_b;

  // Buffers
  reg [31:0] result_buffer;
  reg [31:0] operator1_buffer;
  reg [31:0] operator2_buffer;

  // State definition
  localparam IDLE = 0;
  localparam FETCH_PARAMS = 1;
  localparam LOOP1 = 2;
  localparam LOOP2 = 3;
  localparam LOOP3 = 4;
  localparam LOAD_OPERATOR1 = 5;
  localparam LOAD_OPERATOR2 = 6;
  localparam PERFORM_OPERATION = 7;
  localparam WRITE_RESULT = 8;
  localparam FSM_DONE = 9;

  /* In C we would do two loops like this:
  for (int i = 0; i < height_a; i++) {
    for (int j = 0; j < width_b; j++) {
      matrixC_out[i][j] = 0;  // Initialize the element in the result matrix
      for (int k = 0; k < width_a; k++) {
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
      height_a <= 0;
      width_a <= 0;
      height_b <= 0;
      width_b <= 0;
      mem_operation <= 2'b00;
      addr_o <= 0;
      data_o <= 0;
      // reset FSM
      state <= IDLE;
      i <= 0;
      j <= 0;
      k <= 0;
      done <= 1'b0; // go into ready state
      // reset result register
      result_buffer<= 0;
      operator1_buffer <= 0;
      operator2_buffer <= 0;
    end
    else if (enable) begin
      case (state)
        IDLE: begin
          // Reset indices and result register
          state <= FETCH_PARAMS;
          i <= 0;
          j <= 0;
          k <= 0;
          height_a <= 0;
          width_a <= 0;
          height_b <= 0;
          width_b <= 0;
          addr_o <= 0;
          mem_operation <= 2'b00;
          data_o <= 0;
          done <= 0;
          // reset result register
          result_buffer<= 0;
          operator1_buffer <= 0;
          operator2_buffer <= 0;
        end
        FETCH_PARAMS: begin
          /* Operation registers:
             0: operation
             1: width A
             2: height A
             3: width B
             4: height B
             5: done writing values, go!
          */
          // values for calculating base addresses
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= 1;
          end
          else if ( addr_o < 5 ) begin
            if (mem_opdone) begin
              case (addr_o)
                1: width_a <= data_i; // width A
                2: height_a <= data_i; // height A
                3: width_b <= data_i; // width B
                4: height_b <= data_i; // height B
              endcase
              // Increment address
              addr_o <= addr_o + 1;
            end
          end
          else begin
            state <= LOOP1;
            addr_o <= 0;
            mem_operation <= 2'b00; // done
          end
        end
        LOOP1: begin // for (int i = 0; i < height_a; i++) {
          if (i < height_a) begin
            j <= 0;
            state <= LOOP2;
          end
          else begin
            state <= FSM_DONE;
          end
        end
        LOOP2: begin // for (int j = 0; j < width_b; j++) {
          if (j < width_b ) begin
            state <= LOOP3;
          end
          else begin
            state <= LOOP1;
            i <= i + 1;
          end
        end
        LOOP3: begin // for (int k = 0; k < width_a; k++) {
          if (k < width_a ) begin
            state <= LOAD_OPERATOR1;
          end
          else begin
            state <= WRITE_RESULT;
            j <= j + 1;
          end
        end
        LOAD_OPERATOR1: begin
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_a+i*width_a+k; // matrixA_in[i][k]
          end
          else if (mem_opdone) begin
            operator1_buffer <= data_i;
            //$display("Got operator 1 %d from %x (i=%d, j=%d, k=%d)", $signed(data_i), addr_o, i, j, k);
            state <= LOAD_OPERATOR2;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
        end
        LOAD_OPERATOR2: begin
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_b+k*width_b+j; // matrixB_in[k][j]
          end
          else if (mem_opdone) begin
            operator2_buffer <= data_i;
            //$display("Got operator 2 %d from %x (i=%d, j=%d, k=%d)", $signed(data_i), addr_o, i, j, k);
            state <= PERFORM_OPERATION;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
        end
        PERFORM_OPERATION: begin
          result_buffer <= result_buffer + operator1_buffer * operator2_buffer;
          //$display("%d + %d * %d\n", $signed(result_buffer), $signed(operator1_buffer), $signed(operator2_buffer));
          state <= LOOP3;
          k <= k + 1;
        end
        WRITE_RESULT: begin
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b11; // read
            addr_o <= base_addr_c+i*width_b+j;
            data_o <= result_buffer;
            result_buffer <= 0;
          end
          else if (mem_opdone) begin
            //$display("Wrote result %d to %x (i=%d, j=%d, k=%d)", $signed(data_o), addr_o, i, j, k);
            state <= LOOP2;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
          k <= 0;
        end
        FSM_DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule
