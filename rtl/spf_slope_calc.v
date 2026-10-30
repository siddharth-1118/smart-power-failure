// ============================================================================
// File: spf_slope_calc.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Negative Derivative (dV/dt) Slope Engine for Catastrophic Loss Detection
// ============================================================================

`include "spf_defines.vh"

module spf_slope_calc (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control & Threshold
    input  wire        slope_en_i,
    input  wire [11:0] slope_thresh_i,
    
    // Sample Stream
    input  wire [11:0] filtered_volt_i,
    input  wire        sample_valid_i,
    
    // Outputs
    output reg  [11:0] instant_drop_rate_o,
    output reg         slope_violation_o
);

    reg [11:0] prev_sample;
    reg        first_sample_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_sample         <= 12'd3300;
            first_sample_done   <= 1'b0;
            instant_drop_rate_o <= 12'd0;
            slope_violation_o   <= 1'b0;
        end else begin
            if (sample_valid_i) begin
                if (!first_sample_done) begin
                    prev_sample         <= filtered_volt_i;
                    first_sample_done   <= 1'b1;
                    instant_drop_rate_o <= 12'd0;
                    slope_violation_o   <= 1'b0;
                end else begin
                    prev_sample <= filtered_volt_i;
                    
                    // Check for rapid negative drop (prev_sample > filtered_volt_i)
                    if (prev_sample > filtered_volt_i) begin
                        instant_drop_rate_o <= (prev_sample - filtered_volt_i);
                        if (slope_en_i && ((prev_sample - filtered_volt_i) >= slope_thresh_i)) begin
                            slope_violation_o <= 1'b1;
                        end else begin
                            slope_violation_o <= 1'b0;
                        end
                    end else begin
                        instant_drop_rate_o <= 12'd0;
                        slope_violation_o   <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
