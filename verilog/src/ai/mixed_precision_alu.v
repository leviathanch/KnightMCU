module mixed_precision_alu (
  input clk,
  input rst,
  input [1:0] op, // operation code
  input [15:0] a, // first operand
  input [15:0] b, // second operand
  output reg [15:0] result // result of the operation
);

reg [31:0] temp; // temporary variable for storing the result of the operation

always @(posedge clk) begin
  if (rst) begin
    result <= 0;
  end else begin
    case(op)
      2'b00: // addition
        temp <= $itor(a) + $itor(b);
      2'b01: // multiplication
        temp <= $itor(a) * $itor(b);
      2'b10: // subtraction
        temp <= $itor(a) - $itor(b);
      2'b11: // division
        temp <= $itor(a) / $itor(b);
    endcase
    
    if ($bits(temp) <= 16) begin // result is half precision
      result <= $signed(temp[15:0]);
    end else begin // result is single precision
      result <= $signed(temp[31:16]);
    end
  end
end

endmodule
