parameter N = 16;
parameter M = 4;

module Convolution_Test;
  reg clk;
  reg reset;
  reg [0:N-1][0:63] x1; // matrix
  reg [0:M-1][0:63] x2; // kernel
  wire [0:N-M-1][0:63] y; // convoluted matrix

  initial begin
    // Initialize inputs
    clk = 0;
    reset = 1; // Assert reset initially

    // Initialize x1 matrix
    x1 = {
      $realtobits(0.1), $realtobits(0.2), $realtobits(0.3), $realtobits(0.4),
      $realtobits(0.5), $realtobits(0.6), $realtobits(0.7), $realtobits(0.8),
      $realtobits(0.9), $realtobits(1.0), $realtobits(1.1), $realtobits(1.2),
      $realtobits(1.3), $realtobits(1.4), $realtobits(1.5), $realtobits(1.6)
    };
    // Initialize x2 kernel
    x2 = {
      $realtobits(0.1), $realtobits(0.2),
      $realtobits(0.3), $realtobits(0.4)
    };

    // Enable waveform dumping
    $dumpfile("convolution.vcd");
    $dumpvars(0, Convolution_Test);

    // Reset
    #10 reset = 0;
    #10 reset = 1;

    // Toggle clock and evaluate output
    repeat (200) begin
      #5 clk = ~clk;
    end

    // Print out the values of x1, x2, and y
    for (int i = 0; i < N; i = i + 1) begin
      $display("x1[%0d]: %f", i, $bitstoreal(x1[i]));
    end
    for (int i = 0; i < M; i = i + 1) begin
      $display("x2[%0d]: %f", i, $bitstoreal(x2[i]));
    end
    for (int i = 0; i < N-M; i = i + 1) begin
      $display("y[%0d]: %f", i, $bitstoreal(y[i]));
    end

    // Finish simulation
    $finish;
  end

  // Instantiate Convolution module
  Convolution #(N, M) Convolution_inst (
    .clk(clk),
    .reset(reset),
    .len1(N),
    .x1(x1),
    .len2(M),
    .x2(x2),
    .y(y)
  );

endmodule
