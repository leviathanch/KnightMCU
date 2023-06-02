module Matrix_Convolution (
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
  localparam LOOP4 = 5;
  localparam LOAD_OPERATOR1 = 6;
  localparam LOAD_OPERATOR2 = 7;
  localparam PERFORM_OPERATION = 8;
  localparam WRITE_RESULT = 9;
  localparam FSM_DONE = 10;

  /* In C we would do two loops like this:
    // Convolution operation
    for (int i = 1; i < rows - 1; i++) {
        for (int j = 1; j < cols - 1; j++) {
            int sum = 0;

            for (int k = -1; k <= 1; k++) {
                for (int l = -1; l <= 1; l++) {
                    sum += A[i + k][j + l] * F[k + 1][l + 1];
                }
            }

            result[i][j] = sum;
        }
    }
  But that won't work in Verilog, because for loops work differently,
  so we've got to implement this for loop as a state machine instead.
  */
  
  // Turning the thing on
  // Turning the thing on
  always @(posedge enable) begin
    state <= IDLE;
  end

  always @(posedge clk) begin
    // Assign initial values
    if (reset) begin
      i <= 0;
      j <= 0;
      k <= -1;
      l <= -1;
      data_o <= 0;
      addr_o <= base_addr_c;
      mem_operation <= 2'b00;
      done <= 0;
    end
    // State machine
    else if (enable) begin
      case (state)
        IDLE: begin
          state <= FETCH_PARAMS;
          i <= 0;
          j <= 0;
          k <= -1;
          l <= -1;
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
             1: width A
             2: height A
             3: width B
             4: height B
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
        LOOP1: begin // for (int i = 1; i < rows - 1; i++) {
          if (i < height_a - 1) begin
            state <= LOOP2;
            i <= i + 1;
          end
          else begin
            state <= FSM_DONE;
          end
        end
        LOOP2: begin // for (int j = 1; j < cols - 1; j++) {
          if (j < width_a - 1) begin
            state <= LOOP3;
            j <= j + 1;
          end
          else begin
            state <= LOOP1;
            j <= 0;
          end
        end
        LOOP3: begin // for (int k = -1; k <= 1; k++) {
          if (k < 2) begin
            state <= LOOP4;
            k <= k + 1;
          end
          else begin
            state <= LOAD_OPERATOR1;
            k <= -1;
          end
        end
        LOOP4: begin // for (int l = -1; l <= 1; l++) {
          if (l < 2) begin
            state <= LOAD_OPERATOR1;
            l <= l + 1;
          end
          else begin
            state <= PERFORM_OPERATION;
            l <= -1;
          end
        end
         LOAD_OPERATOR1: begin // A[i + k][j + l]
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_a + ((i + k) * width_a) + (j + l);
          end
          else if (mem_opdone) begin
            operator1_buffer <= data_i;
            state <= LOAD_OPERATOR2;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
        end
        LOAD_OPERATOR2: begin // F[k + 1][l + 1]
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b01; // read
            addr_o <= base_addr_b + ((k + 1) * width_b) + (l + 1);
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
          state <= LOOP4;
        end
        WRITE_RESULT: begin
          if ( addr_o == 0 ) begin
            mem_operation <= 2'b11; // write
            addr_o <= base_addr_c + (i * width_b) + j;
            data_o <= result_buffer;
          end
          else if (mem_opdone) begin
            result_buffer <= 0;
            state <= LOOP2;
            mem_operation <= 2'b00; // done
            addr_o <= 0;
          end
        end
        FSM_DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule
