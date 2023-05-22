module dynamic_quantization (
  input clk,
  input rst,
  input [31:0] data_in,
  input [15:0] data_in_precision,
  input [15:0] data_out_precision,
  output [31:0] data_out
);

reg [31:0] data_out_reg;

always @(posedge clk) begin
  if (rst) begin
    data_out_reg <= 0;
  end else begin
    case ({data_in_precision, data_out_precision})
      // 32-bit to 32-bit
      32'b0000_0001_0000_0001: data_out_reg <= data_in;
      // 32-bit to 16-bit
      32'b0000_0001_0000_0010: data_out_reg <= {data_in[31:16], data_in[15:0]};
      // 16-bit to 32-bit
      32'b0000_0010_0000_0001: data_out_reg <= {data_in[15], {16{data_in[15]}}, data_in[14:0]};
      // 16-bit to 16-bit
      32'b0000_0010_0000_0010: data_out_reg <= data_in;
      // 32-bit to 8-bit
      32'b0000_0001_0000_0100: data_out_reg <= {data_in[31:24], data_in[23:16], data_in[15:8], data_in[7:0]};
      // 8-bit to 32-bit
      32'b0000_0100_0000_0001: data_out_reg <= {8{data_in[7]}, data_in[6:0]};
      // 16-bit to 8-bit
      32'b0000_0010_0000_0100: data_out_reg <= {data_in[15:8], data_in[7]};
      // 8-bit to 16-bit
      32'b0000_0100_0000_0010: data_out_reg <= {{7{data_in[7]}}, data_in[7:0]};
      // 8-bit to 8-bit
      32'b0000_0100_0000_0100: data_out_reg <= data_in;
      default: data_out_reg <= 0;
    endcase
  end
end

assign data_out = data_out_reg;

endmodule
