module Convolution #(parameter num_fpus = 4) (
  input wire clk,
  input wire reset,
  input [0:7] len1, // length of x1
  input [0:7] len2, // length of x2
  input [0:255][0:63] x1, // matrix
  input [0:255][0:63] x2, // kernel
  output reg [0:255][0:63] y // convoluted matrix
);
  reg [0:N-M-1][63:0] temp;
  integer i, k;
  real temp_real;

  always @(posedge clk, negedge reset) begin
    if (!reset) begin
      y <= 0; // Reset the output register
      temp <= $realtobits(0); // Reset the temporary register
    end else begin
      // Perform matrix convolution
      for (i = 0; i < N-M; i = i + 1) begin : ADDER_BLOCK
        temp[i] <= $realtobits(0);
        for (k = 0; k < M; k = k + 1) begin
          temp_real = $bitstoreal(temp[i]) + $bitstoreal(x1[i + k]) * $bitstoreal(x2[k]);
          temp[i] <= $realtobits(temp_real);
        end
      end
      y <= temp; // Assign the temporary register to the output register
    end
  end
endmodule
