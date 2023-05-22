module mixed_precision_alu_tb;

reg [31:0] a;
reg [31:0] b;
reg [2:0] opcode;
wire [31:0] result;

//mixed_precision_alu mpa (
mixed_precision_ALU mpa (
  .clk(clk),
  .a(a),
  .b(b),
  .opcode(opcode),
  .result(result)
);

initial begin
  // Test case 1: Add
  a <= 16'hABCD;
  b <= 16'h1234;
  opcode <= 3'b000;
  #10;
  if (result !== 16'hBE01) $display("Test case 1 failed");

  // Test case 2: Multiply
  a <= 16'h1234;
  b <= 16'h5678;
  opcode <= 3'b101;
  #10;
  if (result !== 32'h06C7C8A0) $display("Test case 2 failed");

  // Test case 3: Max
  a <= 16'hABCD;
  b <= 16'h1234;
  opcode <= 3'b110;
  #10;
  if (result !== 16'hABCD) $display("Test case 3 failed");

  // Test case 4: Min
  a <= 16'hABCD;
  b <= 16'h1234;
  opcode <= 3'b111;
  #10;
  if (result !== 16'h1234) $display("Test case 4 failed");
end

endmodule
