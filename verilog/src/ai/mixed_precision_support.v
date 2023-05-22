module mixed_precision_support (
    input [31:0] a,
    input [31:0] b,
    output [63:0] result
);

reg [31:0] a_fixed;
reg [31:0] b_fixed;

// convert inputs to fixed point
assign a_fixed = $signed({a[31], a[30:0]}) << 16;
assign b_fixed = $signed({b[31], b[30:0]}) << 16;

// perform multiplication
reg [63:0] mult_result;
always @* begin
    mult_result = $signed(a_fixed) * $signed(b_fixed);
end

// convert result back to floating point
assign result = {mult_result[63], mult_result[62:32]} + 
               {mult_result[31], mult_result[30:0]} / 65536;

endmodule
