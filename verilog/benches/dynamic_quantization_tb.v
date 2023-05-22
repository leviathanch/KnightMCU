module dynamic_quantization_tb;

reg clk;
reg rst;
reg [31:0] data_in;
reg [15:0] data_in_precision;
reg [15:0] data_out_precision;
wire [31:0] data_out;

dynamic_quantization dut (
  .clk(clk),
  .rst(rst),
  .data_in(data_in),
  .data_in_precision(data_in_precision),
  .data_out_precision(data_out_precision),
  .data_out(data_out)
);

integer i;

initial begin
  clk = 0;
  rst = 1;
  data_in = 0;
  data_in_precision = 0;
  data_out_precision = 0;

  // reset
  #10 rst = 0;

  // random inputs
  for (i = 0; i < 100; i = i + 1) begin
    data_in = $random;
    data_in_precision = $random;
    data_out_precision = $random;

    // wait for output
    @(posedge clk);

    // check output
    case ({data_in_precision, data_out_precision})
      // 32-bit to 32-bit
      32'b0000_0001_0000_0001: assert (data_out === data_in);
      // 32-bit to 16-bit
      32'b0000_0001_0000_0010: assert (data_out === {data_in[31:16], data_in[15:0]});
      // 16-bit to 32-bit
      32'b0000_0010_0000_0001: assert (data_out === {data_in[15], {16{data_in[15]}}, data_in[14:0]});
      // 16-bit to 16-bit
      32'b0000_0010_0000_0010: assert (data_out === data_in);
      // 32-bit to 8-bit
      32'b0000_0001_0000_0100: assert (data_out === {data_in[31:24], data_in[23:16], data_in[15:8], data_in[7:0]});
      // 8-bit to 32-bit
      32'b0000_0100_0000_0001: assert (data_out === {8{data_in[7]}, data_in[6:0]});
      // 16-bit to 8-bit
      32'b0000_0010_0000_0100: assert (data_out === {data_in[15:8], data_in[7]});
      // 8-bit to 16-bit
      32'b0000_0100_0000_0010: assert (data_out === {{7{data_in[7]}}, data_in[7:0]});
      // 8-bit to 8-bit
      32'b0000_0100_0000_0100: assert (data_out === data_in);
      default: assert (0);
    endcase
  end

  $finish;
end

// clock generator
always #5 clk = ~clk;

endmodule
