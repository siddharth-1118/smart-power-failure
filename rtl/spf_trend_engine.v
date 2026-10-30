// ============================================================================
// File: spf_trend_engine.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Moving-Window Digital Noise Filter and Consecutive Sag Trend Detector
// ============================================================================

`include "spf_defines.vh"

module spf_trend_engine (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control
    input  wire        filter_en_i,
    
    // Sensor Stream Input
    input  wire [11:0] adc_data_i,
    input  wire        adc_valid_i,
    
    // Filtered Outputs
    output reg  [11:0] filtered_volt_o,
    output reg         sample_valid_o,
    output reg         trend_sag_detected_o,
    output reg  [3:0]  consec_drop_cnt_o
);

    // 4-Tap Moving Average Pipeline Registers
    reg [11:0] tap0, tap1, tap2, tap3;
    reg [11:0] prev_filtered_volt;
    reg        init_done;

    // Bit-width extended addition (14-bit to prevent 12-bit overflow)
    wire [13:0] sum_wire = {2'b00, tap0} + {2'b00, tap1} + {2'b00, tap2} + {2'b00, adc_data_i};
    wire [11:0] current_filtered = filter_en_i ? sum_wire[13:2] : adc_data_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tap0                 <= 12'd3300;
            tap1                 <= 12'd3300;
            tap2                 <= 12'd3300;
            tap3                 <= 12'd3300;
            filtered_volt_o      <= 12'd3300;
            prev_filtered_volt   <= 12'd3300;
            sample_valid_o       <= 1'b0;
            trend_sag_detected_o <= 1'b0;
            consec_drop_cnt_o    <= 4'd0;
            init_done            <= 1'b0;
        end else begin
            sample_valid_o <= 1'b0;
            
            if (adc_valid_i) begin
                sample_valid_o  <= 1'b1;
                filtered_volt_o <= current_filtered;
                
                if (filter_en_i) begin
                    tap3 <= tap2;
                    tap2 <= tap1;
                    tap1 <= tap0;
                    tap0 <= adc_data_i;
                end

                // Trend Detection
                if (!init_done) begin
                    prev_filtered_volt   <= current_filtered;
                    init_done            <= 1'b1;
                    consec_drop_cnt_o    <= 4'd0;
                    trend_sag_detected_o <= 1'b0;
                end else begin
                    prev_filtered_volt <= current_filtered;
                    
                    if (current_filtered < prev_filtered_volt) begin
                        if (consec_drop_cnt_o < 4'd15)
                            consec_drop_cnt_o <= consec_drop_cnt_o + 1'b1;
                        
                        if (consec_drop_cnt_o >= 4'd3) begin
                            trend_sag_detected_o <= 1'b1;
                        end
                    end else if (current_filtered > (prev_filtered_volt + 12'd8)) begin
                        consec_drop_cnt_o    <= 4'd0;
                        trend_sag_detected_o <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
