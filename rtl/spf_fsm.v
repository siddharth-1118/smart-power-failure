// ============================================================================
// File: spf_fsm.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Autonomous Power-Health Finite State Machine with Hysteresis
// ============================================================================

`include "spf_defines.vh"

module spf_fsm (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control
    input  wire        enable_i,
    input  wire        auto_recover_i,
    input  wire        int_clear_pulse_i,
    
    // Sensor & Detection Inputs
    input  wire        sample_valid_i,
    input  wire [11:0] filtered_volt_i,
    input  wire [11:0] v_warn_thresh_i,
    input  wire [11:0] v_crit_thresh_i,
    input  wire [11:0] hyst_thresh_i,
    input  wire        trend_sag_i,
    input  wire        slope_violation_i,
    
    // Status & Interrupt Outputs
    output reg  [2:0]  fsm_state_o,
    output reg         pfi_warn_o,
    output reg         shdn_req_o,
    output reg  [2:0]  status_led_o
);

    reg [2:0] state_reg, state_next;
    reg [3:0] recovery_stable_cnt;

    // Synchronous State Register & Recovery Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg           <= `FSM_RESET;
            recovery_stable_cnt <= 4'd0;
        end else if (!enable_i) begin
            state_reg           <= `FSM_RESET;
            recovery_stable_cnt <= 4'd0;
        end else begin
            state_reg <= state_next;
            
            // Increment recovery counter when voltage remains above hysteresis
            if ((state_reg == `FSM_RECOVERY || state_next == `FSM_RECOVERY) && sample_valid_i) begin
                if (filtered_volt_i > (v_warn_thresh_i + hyst_thresh_i)) begin
                    recovery_stable_cnt <= recovery_stable_cnt + 1'b1;
                end else begin
                    recovery_stable_cnt <= 4'd0;
                end
            end else if (state_reg != `FSM_RECOVERY && state_next != `FSM_RECOVERY) begin
                recovery_stable_cnt <= 4'd0;
            end
        end
    end

    // Combinational Next-State Logic
    always @(*) begin
        state_next = state_reg;
        
        case (state_reg)
            `FSM_RESET: begin
                if (sample_valid_i) begin
                    if (filtered_volt_i > v_warn_thresh_i)
                        state_next = `FSM_NORMAL;
                    else
                        state_next = `FSM_SAG_DETECT;
                end
            end

            `FSM_NORMAL: begin
                // Priority 1: Catastrophic sudden drop or critical low voltage
                if (slope_violation_i || (filtered_volt_i <= v_crit_thresh_i)) begin
                    state_next = `FSM_PANIC_SHUTDOWN;
                end
                // Priority 2: Crossing warning threshold
                else if (filtered_volt_i <= v_warn_thresh_i) begin
                    state_next = `FSM_EARLY_WARNING;
                end
                // Priority 3: Trend sag detected while still above warning
                else if (trend_sag_i) begin
                    state_next = `FSM_SAG_DETECT;
                end
            end

            `FSM_SAG_DETECT: begin
                if (slope_violation_i || (filtered_volt_i <= v_crit_thresh_i)) begin
                    state_next = `FSM_PANIC_SHUTDOWN;
                end else if (filtered_volt_i <= v_warn_thresh_i) begin
                    state_next = `FSM_EARLY_WARNING;
                end else if (filtered_volt_i > (v_warn_thresh_i + hyst_thresh_i)) begin
                    state_next = `FSM_NORMAL;
                end
            end

            `FSM_EARLY_WARNING: begin
                if (slope_violation_i || (filtered_volt_i <= v_crit_thresh_i)) begin
                    state_next = `FSM_PANIC_SHUTDOWN;
                end else if (filtered_volt_i > (v_warn_thresh_i + hyst_thresh_i)) begin
                    state_next = `FSM_RECOVERY;
                end
            end

            `FSM_PANIC_SHUTDOWN: begin
                if ((filtered_volt_i > (v_warn_thresh_i + hyst_thresh_i)) && (auto_recover_i || int_clear_pulse_i)) begin
                    state_next = `FSM_RECOVERY;
                end
            end

            `FSM_RECOVERY: begin
                if (slope_violation_i || (filtered_volt_i <= v_crit_thresh_i)) begin
                    state_next = `FSM_PANIC_SHUTDOWN;
                end else if (filtered_volt_i <= v_warn_thresh_i) begin
                    state_next = `FSM_EARLY_WARNING;
                end else if (recovery_stable_cnt >= 4'd2) begin
                    state_next = `FSM_NORMAL;
                end
            end

            default: state_next = `FSM_RESET;
        endcase
    end

    // Output Decode Logic
    always @(*) begin
        fsm_state_o  = state_reg;
        pfi_warn_o   = 1'b0;
        shdn_req_o   = 1'b0;
        status_led_o = 3'b000;

        case (state_reg)
            `FSM_RESET: begin
                status_led_o = 3'b000;
            end
            `FSM_NORMAL: begin
                status_led_o = 3'b001; // Green
            end
            `FSM_SAG_DETECT: begin
                pfi_warn_o   = 1'b1;   // Early warning alert
                status_led_o = 3'b010; // Yellow
            end
            `FSM_EARLY_WARNING: begin
                pfi_warn_o   = 1'b1;   // Early Warning Interrupt active
                status_led_o = 3'b010; // Yellow
            end
            `FSM_PANIC_SHUTDOWN: begin
                pfi_warn_o   = 1'b1;   // Warning remains asserted
                shdn_req_o   = 1'b1;   // Emergency shutdown asserted
                status_led_o = 3'b100; // Red
            end
            `FSM_RECOVERY: begin
                pfi_warn_o   = 1'b1;   // Keep warning until confirmed normal
                status_led_o = 3'b011; // Cyan / Orange
            end
            default: ;
        endcase
    end

endmodule
