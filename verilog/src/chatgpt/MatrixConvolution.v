module MatrixConvolution (
  input wire clk,
  input wire rst,
  input wire [9:0] input_rows,     // Number of rows in the input matrix
  input wire [9:0] input_cols,     // Number of columns in the input matrix
  input wire [9:0] filter_rows,    // Number of rows in the filter
  input wire [9:0] filter_cols,    // Number of columns in the filter
  input wire [31:0] input_matrix [0:1023][0:1023],   // Input matrix
  input wire [31:0] filter [0:1023][0:1023],         // Filter matrix
  output wire [31:0] conv_matrix [0:1023][0:1023]    // Convolved matrix
);

  // Internal parameters
  parameter IDLE = 2'b00;
  parameter LOAD_INPUT = 2'b01;
  parameter LOAD_FILTER = 2'b10;
  parameter CONVOLVE = 2'b11;

  // Internal signals
  reg [1:0] state;
  reg [9:0] input_row_counter;
  reg [9:0] input_col_counter;
  reg [9:0] filter_row_counter;
  reg [9:0] filter_col_counter;
  reg [31:0] temp_sum;
  reg [31:0] conv_element;
  reg [31:0] result;

  // Reset and state control
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      input_row_counter <= 0;
      input_col_counter <= 0;
      filter_row_counter <= 0;
      filter_col_counter <= 0;
      temp_sum <= 0;
      conv_element <= 0;
    end else begin
      case (state)
        IDLE:
          state <= LOAD_INPUT;
        LOAD_INPUT:
          if (input_row_counter == input_rows - 1 && input_col_counter == input_cols - 1)
            state <= LOAD_FILTER;
          else
            state <= LOAD_INPUT;
        LOAD_FILTER:
          if (filter_row_counter == filter_rows - 1 && filter_col_counter == filter_cols - 1)
            state <= CONVOLVE;
          else
            state <= LOAD_FILTER;
        CONVOLVE:
          if (input_row_counter == input_rows - 1 && input_col_counter == input_cols - 1)
            state <= IDLE;
          else
            state <= CONVOLVE;
      endcase
    end
  end

  // Convolution operation
  always @(posedge clk) begin
    case (state)
      IDLE:
        result <= 0;
      LOAD_INPUT:
        if (input_row_counter < input_rows && input_col_counter < input_cols)
          conv_element <= input_matrix[input_row_counter][input_col_counter];
      LOAD_FILTER:
        if (filter_row_counter < filter_rows && filter_col_counter < filter_cols)
          conv_element <= filter[filter_row_counter][filter_col_counter];
      CONVOLVE:
        if (filter_row_counter < filter_rows && filter_col_counter < filter_cols) begin
          temp_sum <= temp_sum + (conv_element * input_matrix[input_row_counter][input_col_counter]);
        end
        if (input_col_counter == input_cols - 1) begin
          if (input_row_counter == input_rows - 1) begin
            conv_matrix[input_row_counter][input_col_counter] <= temp_sum;
            result <= temp_sum;
          end else begin
            conv_matrix[input_row_counter][input_col_counter] <= temp_sum;
            temp_sum <= 0;
          end
        end
    endcase
  end

  // Input and filter counters
  always @(posedge clk) begin
    case (state)
      LOAD_INPUT:
        if (input_col_counter < input_cols - 1)
          input_col_counter <= input_col_counter + 1;
        else if (input_row_counter < input_rows - 1) begin
          input_col_counter <= 0;
          input_row_counter <= input_row_counter + 1;
        end
      LOAD_FILTER:
        if (filter_col_counter < filter_cols - 1)
          filter_col_counter <= filter_col_counter + 1;
        else if (filter_row_counter < filter_rows - 1) begin
          filter_col_counter <= 0;
          filter_row_counter <= filter_row_counter + 1;
        end
      CONVOLVE:
        if (filter_col_counter < filter_cols - 1)
          filter_col_counter <= filter_col_counter + 1;
        else if (filter_row_counter < filter_rows - 1) begin
          filter_col_counter <= 0;
          filter_row_counter <= filter_row_counter + 1;
        end
        if (input_col_counter < input_cols - 1)
          input_col_counter <= input_col_counter + 1;
        else if (input_row_counter < input_rows - 1) begin
          input_col_counter <= 0;
          input_row_counter <= input_row_counter + 1;
        end
    endcase
  end

  // Output assignment
  assign conv_matrix[input_row_counter][input_col_counter] = result;

endmodule
