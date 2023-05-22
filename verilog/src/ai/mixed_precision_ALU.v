module mixed_precision_ALU (
    input wire [15:0] op_a_half, // input operand a in half precision
    input wire [31:0] op_a_single, // input operand a in single precision
    input wire [1:0] op_b_half, // input operand b in half precision
    input wire [31:0] op_b_single, // input operand b in single precision
    input wire [2:0] opcode, // operation code
    output wire [15:0] result_half, // result in half precision
    output wire [31:0] result_single // result in single precision
);
reg [15:0] result_half;
reg [31:0] result_single;

always @(*) begin
    case (opcode)
        3'b000: // addition
            result_half = op_a_half + op_b_half;
            result_single = op_a_single + op_b_single;
        3'b001: // subtraction
            result_half = op_a_half - op_b_half;
            result_single = op_a_single - op_b_single;
        3'b010: // multiplication
            result_half = op_a_half * op_b_half;
            result_single = op_a_single * op_b_single;
        3'b011: // division
            result_half = op_a_half / op_b_half;
            result_single = op_a_single / op_b_single;
        3'b100: // square root
            result_half = $sqrt(op_a_half);
            result_single = $sqrt(op_a_single);
        3'b101: // exponential
            result_half = $exp(op_a_half);
            result_single = $exp(op_a_single);
        3'b110: // logarithm
            result_half = $log(op_a_half);
            result_single = $log(op_a_single);
        3'b111: // trigonometric functions
            result_half = $sin(op_a_half);
            result_single = $sin(op_a_single);
    endcase
end

assign result_half = (op_b_half[1]) ? $signed(result_half) : result_half; // convert result to signed if necessary
assign result_single = (op_b_single[31]) ? $signed(result_single) : result_single; // convert result to signed if necessary

endmodule
