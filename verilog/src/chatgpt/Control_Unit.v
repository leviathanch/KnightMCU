module Control_Unit(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
  input wire clk,
  input wire reset,
  input wire [31:0] status,
  input wire [31:0] operation,
  input wire matrix_mult_done,
  input wire matrix_conv_done,
  output reg multiplier_enable,
  output reg convolution_enable,
  output reg finished
);
  reg started;
  reg busy;

  always @(posedge clk) begin
    if (reset) begin
      busy <= 1'b0;
      started <= 1'b0;
      multiplier_enable <= 1'b0;
      convolution_enable <= 1'b0;
      finished <= 0;
    end
    else if ( started && busy ) begin
      started <= 0;
    end
    else if ( status == 32'h0000_0000 && finished ) begin
       finished <= 0;
    end
    else if ( !finished ) begin
      case ( operation ) // Register 1 holds the operation to be executed
        // Enable corresponding module based on operation value in operation register
        `MULTIPLICATION_OPERATION: begin // matrix multiplication
          if( matrix_mult_done && busy ) begin
            busy <= 1'b0;
            multiplier_enable <= 1'b0; // Enable matrix multiplication module
            finished <= 1; // Done
          end
          else if ( status == 32'hffff_ffff ) begin
            busy <= 1'b1; // indicate that we started operation
            multiplier_enable <= 1'b1; // Enable matrix multiplication module
            started <= 1'b1;
          end
        end
        `CONVOLUTION_OPERATION: begin // matrix convolution
          if( matrix_conv_done && busy ) begin
            busy <= 1'b0;
            convolution_enable <= 1'b0; // Enable matrix multiplication module
            finished <= 1; // Done
          end
          else if ( status == 32'hffff_ffff ) begin
            busy <= 1'b1; // indicate that we started operation
            convolution_enable <= 1'b1; // Enable matrix multiplication module
            started <= 1'b1;
          end
        end
      endcase
    end
  end

endmodule
