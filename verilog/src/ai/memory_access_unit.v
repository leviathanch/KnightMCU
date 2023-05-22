module memory_access_unit (
  input clk,
  input [31:0] addr,
  input [31:0] data_in,
  input [1:0] mem_op,
  output reg [31:0] data_out
);

reg [31:0] mem [1024]; // Memory with 1024 locations

always @(posedge clk) begin
  case (mem_op)
    2'b00: data_out <= mem[addr]; // Read
    2'b01: mem[addr] <= data_in; // Write
    2'b10: mem[addr] <= mem[addr] + data_in; // Add
    2'b11: mem[addr] <= mem[addr] - data_in; // Subtract
    default: data_out <= 0; // Error
  endcase
end

endmodule
