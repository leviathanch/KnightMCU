module softmax_unit (
    input logic clk, // clock input
    input logic rst, // reset input
    input logic [31:0] data_in, // input data
    output logic [31:0] data_out // output data
);

// Define parameters
parameter int EXP_WIDTH = 8; // exponent width
parameter int MANT_WIDTH_H = 10; // mantissa width for half precision
parameter int MANT_WIDTH_S = 23; // mantissa width for single precision
parameter int MANT_WIDTH = 23; // default mantissa width
parameter int BIAS_H = 15; // bias for half precision
parameter int BIAS_S = 127; // bias for single precision

// Define variables
logic [31:0] data_exp;
logic [MANT_WIDTH-1:0] data_mant;
logic [EXP_WIDTH-1:0] exp_max;
logic [EXP_WIDTH-1:0] exp_min;
logic [31:0] data_exp_max;
logic [31:0] data_exp_min;
logic [MANT_WIDTH-1:0] exp_val;
logic [31:0] exp_val_fp;
logic [31:0] exp_val_half;
logic [31:0] exp_val_single;
logic [31:0] exp_bias;
logic [31:0] exp_bias_half;
logic [31:0] exp_bias_single;
logic [31:0] exp_diff;
logic [MANT_WIDTH-1:0] exp_diff_mant;
logic [31:0] exp_diff_fp;
logic [31:0] exp_diff_half;
logic [31:0] exp_diff_single;
logic [31:0] exp_diff_shifted;
logic [MANT_WIDTH-1:0] mant_max;
logic [31:0] mant_max_fp;
logic [31:0] mant_max_half;
logic [31:0] mant_max_single;
logic [31:0] mant_sum;
logic [31:0] mant_sum_fp;
logic [31:0] mant_sum_half;
logic [31:0] mant_sum_single;
logic [31:0] mant_diff;
logic [31:0] mant_diff_fp;
logic [31:0] mant_diff_half;
logic [31:0] mant_diff_single;
logic [31:0] mant_diff_shifted;
logic [31:0] mant_out_fp;
logic [31:0] mant_out_half;
logic [31:0] mant_out_single;
logic [31:0] data_out_fp;
logic [31:0] data_out_half;
logic [31:0] data_out_single;

// Calculate exponent and mantissa values
always_comb begin
    data_exp = data_in[30:23];
    data_mant = data_in[22:0];
end

// Calculate exponent value range
always_comb begin
    exp_max = EXP_WIDTH'h01111111;
    exp_min = EXP_WIDTH'h00000001;
end

// Calculate exponent bias values
always_comb begin
    exp_bias = {BIAS_S{1'b1}};
    exp_bias_half = {BIAS_H{1'b1}};
    exp_bias_single = {BIAS_S{1'b1}};
end

// Calculate exponent value
always_comb begin
    if (data_exp >= exp_max) begin
        data_exp_max = {EXP_WIDTH'h0, data_exp};
        exp_val_fp = exp_bias;
        exp_val_half = exp_bias_half;
        exp_val_single = exp_bias_single;
    end
    else if (data_exp <= exp_min) begin
        data_exp_min = {EXP_WIDTH'h0, data_exp};
        exp_val_fp = {EXP_WIDTH'h0, EXP_WIDTH'h00000001};
        exp_val_half = {EXP_WIDTH'h0, EXP_WIDTH'h0001};
        exp_val_single = {EXP_WIDTH'h0, EXP_WIDTH'h00000001};
    end
    else begin
        exp_val = data_exp - EXP_WIDTH'h01111110;
        exp_val_fp = {EXP_WIDTH'h0, exp_val};
        exp_val_half = exp_val_fp - exp_bias_half;
        exp_val_single = exp_val_fp - exp_bias_single;
    end
end

// Calculate exponent difference value
always_comb begin
    if (data_exp >= exp_max) begin
        exp_diff_fp = {EXP_WIDTH'h0, EXP_WIDTH'h00000000};
        exp_diff_half = {EXP_WIDTH'h0, EXP_WIDTH'h0000};
        exp_diff_single = {EXP_WIDTH'h0, EXP_WIDTH'h00000000};
        exp_diff_shifted = {MANT_WIDTH'h0, 1'b1};
    end
    else if (data_exp <= exp_min) begin
        exp_diff_fp = {EXP_WIDTH'h0, data_exp_max[7:1]};
        exp_diff_half = {EXP_WIDTH'h0, data_exp_max[7:4]};
        exp_diff_single = {EXP_WIDTH'h0, data_exp_max[7:1]};
        exp_diff_shifted = {MANT_WIDTH'h0, 1'b1};
    end
    else begin
        exp_diff = exp_val_fp - data_exp_max;
        exp_diff_fp = {EXP_WIDTH'h0, exp_diff[EXP_WIDTH-2:0]};
        exp_diff_half = {EXP_WIDTH'h0, exp_diff[EXP_WIDTH-2:EXP_WIDTH-5]};
        exp_diff_single = {EXP_WIDTH'h0, exp_diff[EXP_WIDTH-2:0]};
        exp_diff_shifted = {MANT_WIDTH'h0, 1'b1} << exp_diff[EXP_WIDTH-2:0];
    end
end

// Calculate maximum mantissa value
always_comb begin
    mant_max = {MANT_WIDTH'h0, 1'b1} << MANT_WIDTH;
end

// Calculate sum of all mantissa values
always_comb begin
    mant_sum = mant_max | data_mant;
    mant_sum_fp = {MANT_WIDTH'h0, mant_sum};
    mant_sum_half = {MANT_WIDTH'h0, mant_sum};
    mant_sum_single = {MANT_WIDTH'h0, mant_sum};
end

// Calculate difference between each mantissa value and the maximum mantissa value
always_comb begin
    mant_diff = mant_max - data_mant;
    mant_diff_fp = {MANT_WIDTH'h0, mant_diff};
    mant_diff_half = {MANT_WIDTH'h0, mant_diff};
    mant_diff_single = {MANT_WIDTH'h0, mant_diff};
end

// Calculate shifted difference value
always_comb begin
    mant_diff_shifted = mant_diff_fp >> EXP_WIDTH;
end

// Calculate output mantissa values
always_comb begin
    mant_out_fp = (mant_diff_shifted * mant_sum_fp) >> MANT_WIDTH;
    mant_out_half = (mant_diff_shifted * mant_sum_half) >> MANT_WIDTH;
    mant_out_single = (mant_diff_shifted * mant_sum_single) >> MANT_WIDTH;
end

// Calculate output data values
always_comb begin
    if (data_exp >= exp_max) begin
        data_out_fp = {EXP_WIDTH'h0, EXP_WIDTH'h00000000};
        data_out_half = {EXP_WIDTH'h0, EXP_WIDTH'h0000};
        data_out_single = {EXP_WIDTH'h0, EXP_WIDTH'h00000000};
    end
    else if (data_exp <= exp_min) begin
        data_out_fp = {EXP_WIDTH'h0, mant_out_fp[MANT_WIDTH-2:MANT_WIDTH-25]};
        data_out_half = {EXP_WIDTH'h0, mant_out_half[MANT_WIDTH-2:MANT_WIDTH-11]};
        data_out_single = {EXP_WIDTH'h0, mant_out_single[MANT_WIDTH-2:MANT_WIDTH-26]};
    end
    else begin
        data_out_fp = {exp_val_fp, mant_out_fp[MANT_WIDTH-2:MANT_WIDTH-25]};
        data_out_half = {exp_val_half, mant_out_half[MANT_WIDTH-2:MANT_WIDTH-11]};
        data_out_single = {exp_val_single, mant_out_single[MANT_WIDTH-2:MANT_WIDTH-26]};
    end
end

// Assign output data
always_ff @(posedge clk) begin
    if (rst) begin
        data_out <= {32{1'b0}};
    end
    else begin
        case (data_in[31:30])
            2'b00: data_out <= data_out_half;
            2'b01: data_out <= data_out_single;
            2'b10: data_out <= data_out_fp;
            default: data_out <= data_out_fp;
        endcase
    end
end

endmodule
