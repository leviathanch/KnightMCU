module Matrix_Convolution (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  input wire         clk,
  input wire         reset,
  input wire         enable,
  input wire         mem_opdone,
  input wire [31:0]  data_i,
  output reg [31:0]  data_o,
  output reg [31:0]  addr_o,
  output reg [1:0]   mem_operation, // Read 01 /Write 11 /None 00
  output reg         done
);

  // FSM variables
  reg [31:0] i;
  reg [31:0] j;
  reg [31:0] k;
  reg [31:0] l;

  reg [31:0] state;

  // Dynamic address calculation
  reg [31:0] width_matrix; // width A
  reg [31:0] height_matrix; // height A
  reg [31:0] width_filter; // width filter
  reg [31:0] height_filter; // height filter

  wire [31:0] base_addr_a;
  wire [31:0] base_addr_filter;
  wire [31:0] base_addr_result;

  assign base_addr_a = 32'h0000_0004; // 4 parameters
  assign base_addr_filter = base_addr_a + height_matrix*width_matrix;
  assign base_addr_result = base_addr_filter + height_matrix*width_matrix + height_filter*width_filter;

  // Buffers
  reg [31:0] result_buffer;
  reg [31:0] operator1_buffer;
  reg [31:0] operator2_buffer;

  // State definition
  localparam START = 0;
  localparam FETCH_PARAMS = 1;
  localparam LOOP1 = 2;
  localparam LOOP2 = 3;
  localparam LOOP3 = 4;
  localparam LOOP4 = 5;
  localparam LOAD_OPERATOR1 = 6;
  localparam LOAD_OPERATOR2 = 7;
  localparam PERFORM_OPERATION = 8;
  localparam WRITE_RESULT = 9;
  localparam FSM_DONE = 10;

  /* In C we would do two loops like this:
    // Convolution operation
    for (int i = 0; i < height_matrix - height_filter + 1; i++) {
        for (int j = 0; j < width_matrix - width_filter + 1; j++) {
            int sum = 0;

            for (int k = 0; k < height_filter; k++) {
                for (int l = 0; l < width_filter; l++) {
                    sum += A[i + k][j + l] * F[k][l];
                }
            }

            result[i][j] = sum;
        }
    }
    The result matrix has the dimension (width_matrix - width_filter - 1)x (height_matrix - height_filter - 1)
  But that won't work in Verilog, because for loops work differently,
  so we've got to implement this for loop as a state machine instead.
  */
  reg enable_edge;
  always @(posedge enable) begin
    enable_edge <= 1;
  end
  always @(posedge clk) begin
    // Assign initial values
    if (reset) begin
      height_matrix <= 0;
      width_matrix <= 0;
      height_filter <= 0;
      width_filter <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      l <= 0;
      data_o <= 0;
      addr_o <= 0;;
      mem_operation <= 2'b00;
      done <= 0;
      state <= FSM_DONE;
      // reset result register
      result_buffer<= 0;
      operator1_buffer <= 0;
      operator2_buffer <= 0;
      enable_edge <= 0;
    end
    // State machine
    else begin
      case (state)
        START: begin
          if (enable) state <= FETCH_PARAMS;
          height_matrix <= 0;
          width_matrix <= 0;
          height_filter <= 0;
          width_filter <= 0;
          i <= 0;
          j <= 0;
          k <= 1;
          l <= 2;
          height_matrix <= 0;
          width_matrix <= 0;
          height_filter <= 0;
          width_filter <= 0;
          addr_o <= 0;
          mem_operation <= 2'b00;
          data_o <= 0;
          done <= 0;
          // reset result register
          result_buffer<= 0;
          operator1_buffer <= 0;
          operator2_buffer <= 0;
          enable_edge <= 0;
        end
        FETCH_PARAMS: begin
          /* Operation registers:
             0: width A
             1: height A
             2: width B
             3: height B
          */
          // values for calculating base addresses
          if ( addr_o == 0 && mem_operation != 2'b01 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= 0;
          end
          else if ( addr_o < 5 ) begin
            if (mem_opdone) begin
              case (addr_o)
                0: width_matrix <= data_i; // width A
                1: height_matrix <= data_i; // height A
                2: width_filter <= data_i; // width B
                3: height_filter <= data_i; // height B
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
        LOOP1: begin // for (int i = 0; i < height_matrix - height_filter + 1; i++) {
          if (i < height_matrix - height_filter + 1) begin
            j <= 0;
            state <= LOOP2;
          end
          else begin
            state <= FSM_DONE;
          end
        end
        LOOP2: begin // for (int j = 0; j < width_matrix - width_filter + 1; j++) {
          //$display("LOOP2 j=%d", $signed(j));
          if ( j < width_matrix - width_filter + 1) begin
            k <= 0;
            state <= LOOP3;
          end
          else begin
            state <= LOOP1;
            i <= i + 1;
          end
        end
        LOOP3: begin // for (int k = 0; k < height_filter; k++) {
        //$display("LOOP3 k=%d", $signed(k));
          if (k < height_filter) begin
            l <= 0;
            state <= LOOP4;
          end
          else begin
            state <= WRITE_RESULT;
          end
        end
        LOOP4: begin // for (int l = 0; l < width_filter; l++) {
          //$display("LOOP4 l=%d", $signed(l));
          if (l < width_filter) begin
            state <= LOAD_OPERATOR1;
          end
          else begin
            state <= LOOP3;
            k <= k + 1;
          end
        end
        /* Fetch operator 1 and 2 */
        LOAD_OPERATOR1: begin // A[i + k][j + l]
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_a + (i+k)*width_matrix + (j+l);
          end
          else if (mem_opdone) begin
            operator1_buffer <= data_i;
            state <= LOAD_OPERATOR2;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end          
        end
        LOAD_OPERATOR2: begin // F[k][l]
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_filter + k*width_filter + l;
          end
          else if (mem_opdone) begin
            operator2_buffer <= data_i;
            state <= PERFORM_OPERATION;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
        end
        PERFORM_OPERATION: begin
          result_buffer <= result_buffer + operator1_buffer * operator2_buffer;
          l <= l + 1;
          state <= LOOP4;
        end

        /* Write out result into RAM */
        WRITE_RESULT: begin
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b11; // write
            addr_o <= base_addr_result + i*(width_matrix-width_filter+1) + j;
            data_o <= result_buffer;
          end
          else if (mem_opdone) begin
            result_buffer <= 0;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
            state <= LOOP2;
            j <= j + 1;
          end
        end
        /* Done state */
        FSM_DONE: begin
          done <= 1;
          // Turning the thing on
          if (enable_edge) state <= START;
        end
      endcase
    end
  end

endmodule
