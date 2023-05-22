module memory_access_unit_tb;

reg [31:0] addr;
reg [31:0] data_in;
reg [1:0] mem_op;
wire [31:0] data_out;

memory_access_unit mau (
  .clk(clk),
  .addr(addr),
  .data_in(data_in),
  .mem_op(mem_op),
  .data_out(data_out)
);

initial begin
  // Test case 1: Write and Read
  addr <= 10;
  data_in <= 16'hABCD;
  mem_op <= 2'b01;
  #10;
  addr <= 10;
  mem_op <= 2'b00;
  #10;
  if (data_out !== 16'hABCD) $display("Test case 1 failed");

  // Test case 2: Add
  addr <= 10;
  data_in <= 16'h1234;
  mem_op <= 2'b10;
  #10;
  addr <= 10;
  mem_op <= 2'b00;
  #10;
  if (data_out !== 16'h2468) $display("Test case 2 failed");

  // Test case 3: Subtract
  addr <= 10;
  data_in <= 16'h1234;
  mem_op <= 2'b11;
  #10;
  addr <= 10;
  mem_op <= 2'b00;
  #10;
  if (data_out !== 16'h1234) $display("Test case 3 failed");
end

endmodule
