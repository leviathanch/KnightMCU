module MatrixConvolution_TB;

  // Parameters
  parameter INPUT_ROWS = 4;      // Number of rows in the input matrix
  parameter INPUT_COLS = 4;      // Number of columns in the input matrix
  parameter FILTER_ROWS = 3;     // Number of rows in the filter
  parameter FILTER_COLS = 3;     // Number of columns in the filter

  // Signals
  reg clk;
  reg rst;
  reg [9:0] input_row;
  reg [9:0] input_col;
  reg [9:0] filter_row;
  reg [9:0] filter_col;
  reg [31:0] input_matrix [0:1023][0:1023];
  reg [31:0] filter [0:1023][0:1023];
  wire [31:0] conv_matrix [0:1023][0:1023];

  // Instantiate DUT
  MatrixConvolution dut (
    .clk(clk),
    .rst(rst),
    .input_rows(INPUT_ROWS),
    .input_cols(INPUT_COLS),
    .filter_rows(FILTER_ROWS),
    .filter_cols(FILTER_COLS),
    .input_matrix(input_matrix),
    .filter(filter),
    .conv_matrix(conv_matrix)
  );

  // Clock generation
  always begin
    #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst = 1;
    #10 rst = 0;
  end

  // Test stimulus
  initial begin
    // Initialize input matrix and filter with test data here
    // Example:
    input_matrix[0][0] = 1;
    input_matrix[0][1] = 2;
    input_matrix[0][2] = 3;
    // ...

    filter[0][0] = 1;
    filter[0][1] = 0;
    filter[0][2] = 1;
    // ...

    // Provide appropriate input row, column, and filter row, column values to cover all elements
    // You can use nested loops to iterate through the input matrix and filter

    // Example:
    for (input_row = 0; input_row < INPUT_ROWS; input_row = input_row + 1) begin
      for (input_col = 0; input_col < INPUT_COLS; input_col = input_col + 1) begin
        for (filter_row = 0; filter_row < FILTER_ROWS; filter_row = filter_row + 1) begin
          for (filter_col = 0; filter_col < FILTER_COLS; filter_col = filter_col + 1) begin
            #5;  // Wait for one clock cycle
            // Provide the input row, column, filter row, and column values to the DUT
            // Example:
            {input_matrix[input_row][input_col], filter[filter_row][filter_col]} <= {input_row, input_col, filter_row, filter_col};
          end
        end
      end
    end

    // Wait for the convolution to complete
    // You can calculate the expected convolved matrix and compare it with the actual conv_matrix output

    // Example:
    #10;
    // Compare the conv_matrix output with the expected convolved matrix
    // Example:
    // assert conv_matrix[0][0] == expected_result_0_0;
    // assert conv_matrix[0][1] == expected_result_0_1;
    // ...
  end

endmodule
