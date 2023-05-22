module conv_fp_unit (
  input wire clk,              // clock
  input wire reset,            // asynchronous reset
  
  // input data
  input wire [31:0] in_data,   // input data
  input wire [31:0] weight,    // weight
  input wire [31:0] bias,      // bias
  
  // output data
  output wire [31:0] out_data  // output data
);

  // declare variables
  reg [15:0] in_data_fp16;     // input data in half precision
  reg [31:0] in_data_fp32;     // input data in single precision
  reg [15:0] weight_fp16;      // weight in half precision
  reg [31:0] weight_fp32;      // weight in single precision
  reg [15:0] bias_fp16;        // bias in half precision
  reg [31:0] bias_fp32;        // bias in single precision
  reg [15:0] out_data_fp16;    // output data in half precision
  reg [31:0] out_data_fp32;    // output data in single precision
  
  // convert input data to half and single precision
  assign in_data_fp16 = $shortrealtobits($realtoshortreal($bitstoreal(in_data)));
  assign in_data_fp32 = $bitstoreal(in_data);
  
  // convert weight to half and single precision
  assign weight_fp16 = $shortrealtobits($realtoshortreal($bitstoreal(weight)));
  assign weight_fp32 = $bitstoreal(weight);
  
  // convert bias to half and single precision
  assign bias_fp16 = $shortrealtobits($realtoshortreal($bitstoreal(bias)));
  assign bias_fp32 = $bitstoreal(bias);
  
  // perform convolution in half precision
  always @ (posedge clk) begin
    if (reset) begin
      out_data_fp16 <= 0;
    end else begin
      out_data_fp16 <= in_data_fp16 * weight_fp16 + bias_fp16;
    end
  end
  
  // convert output data from half to single precision
  always @ (posedge clk) begin
    if (reset) begin
      out_data_fp32 <= 0;
    end else begin
      out_data_fp32 <= $bitsorealtoshortreal($shortrealtobits(out_data_fp16));
    end
  end
  
  // output data in single precision
  assign out_data = $realtobits(out_data_fp32);
  
endmodule
