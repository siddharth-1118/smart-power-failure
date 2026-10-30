// ============================================================================
// File: spf_predictor_top.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Top-Level ASIC Chip Module integrating Filter, Slope Detector,
//              Programmable Register Bank, and Autonomous Power-Health FSM
// ============================================================================

`include "spf_defines.vh"

module spf_predictor_top (
    // Primary Clock and Active-Low Asynchronous Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Digital Voltage Sensor Streaming Interface (from ADC)
    input  wire [11:0] adc_data_i,
    input  wire        adc_valid_i,
    
    // Memory-Mapped Control Register Bus Interface (Host MCU / APB-like)
    input  wire [3:0]  reg_addr_i,
    input  wire [15:0] reg_wdata_i,
    input  wire        reg_we_i,
    input  wire        reg_re_i,
    output wire [15:0] reg_rdata_o,
    output wire        reg_ack_o,
    
    // Early-Warning Power Fail & Shutdown Flag Outputs
    output wire        pfi_warn_o,    // Active-High Early Power-Fail Warning Interrupt
    output wire        pfi_warn_n_o,  // Active-Low Early Power-Fail Warning Interrupt
    output wire        shdn_req_o,    // Active-High Emergency Shutdown Trigger
    output wire [2:0]  status_led_o   // Visual System Health Diagnostics (G/Y/R)
);

    // Internal Interconnect Wires
    wire        ctrl_enable;
    wire        ctrl_slope_en;
    wire        ctrl_filter_en;
    wire        ctrl_auto_recover;
    wire [11:0] v_warn_thresh;
    wire [11:0] v_crit_thresh;
    wire [11:0] slope_thresh;
    wire [11:0] hyst_thresh;
    wire        int_clear_pulse;
    
    wire [11:0] filtered_volt;
    wire        sample_valid;
    wire        trend_sag_detected;
    wire [3:0]  consec_drop_cnt;
    
    wire [11:0] instant_drop_rate;
    wire        slope_violation;
    
    wire [2:0]  fsm_state;
    wire        pfi_warn_internal;
    wire        shdn_req_internal;

    // Active-Low Inversion for pfi_warn_n_o
    assign pfi_warn_o   = pfi_warn_internal;
    assign pfi_warn_n_o = ~pfi_warn_internal;
    assign shdn_req_o   = shdn_req_internal;

    // ------------------------------------------------------------------------
    // Sub-Block 1: Memory-Mapped Register Bank
    // ------------------------------------------------------------------------
    spf_reg_bank u_reg_bank (
        .clk                 (clk),
        .rst_n               (rst_n),
        .reg_addr            (reg_addr_i),
        .reg_wdata           (reg_wdata_i),
        .reg_we              (reg_we_i),
        .reg_re              (reg_re_i),
        .reg_rdata           (reg_rdata_o),
        .reg_ack             (reg_ack_o),
        
        .fsm_state_i         (fsm_state),
        .pfi_warn_active_i   (pfi_warn_internal),
        .shdn_req_active_i   (shdn_req_internal),
        .slope_violation_i   (slope_violation),
        .filtered_volt_i     (filtered_volt),
        
        .ctrl_enable_o       (ctrl_enable),
        .ctrl_slope_en_o     (ctrl_slope_en),
        .ctrl_filter_en_o    (ctrl_filter_en),
        .ctrl_auto_recover_o (ctrl_auto_recover),
        .v_warn_thresh_o     (v_warn_thresh),
        .v_crit_thresh_o     (v_crit_thresh),
        .slope_thresh_o      (slope_thresh),
        .hyst_thresh_o       (hyst_thresh),
        .int_clear_pulse_o   (int_clear_pulse)
    );

    // ------------------------------------------------------------------------
    // Sub-Block 2: Moving-Window Digital Filter and Trend Detector
    // ------------------------------------------------------------------------
    spf_trend_engine u_trend_engine (
        .clk                  (clk),
        .rst_n                (rst_n),
        .filter_en_i          (ctrl_filter_en),
        .adc_data_i           (adc_data_i),
        .adc_valid_i          (adc_valid_i & ctrl_enable),
        .filtered_volt_o      (filtered_volt),
        .sample_valid_o       (sample_valid),
        .trend_sag_detected_o (trend_sag_detected),
        .consec_drop_cnt_o    (consec_drop_cnt)
    );

    // ------------------------------------------------------------------------
    // Sub-Block 3: Negative Derivative (dV/dt) Slope Engine
    // ------------------------------------------------------------------------
    spf_slope_calc u_slope_calc (
        .clk                 (clk),
        .rst_n               (rst_n),
        .slope_en_i          (ctrl_slope_en),
        .slope_thresh_i      (slope_thresh),
        .filtered_volt_i     (filtered_volt),
        .sample_valid_i      (sample_valid),
        .instant_drop_rate_o (instant_drop_rate),
        .slope_violation_o   (slope_violation)
    );

    // ------------------------------------------------------------------------
    // Sub-Block 4: Autonomous Power-Health Finite State Machine (FSM)
    // ------------------------------------------------------------------------
    spf_fsm u_fsm (
        .clk               (clk),
        .rst_n             (rst_n),
        .enable_i          (ctrl_enable),
        .auto_recover_i    (ctrl_auto_recover),
        .int_clear_pulse_i (int_clear_pulse),
        .sample_valid_i    (sample_valid),
        .filtered_volt_i   (filtered_volt),
        .v_warn_thresh_i   (v_warn_thresh),
        .v_crit_thresh_i   (v_crit_thresh),
        .hyst_thresh_i     (hyst_thresh),
        .trend_sag_i       (trend_sag_detected),
        .slope_violation_i (slope_violation),
        .fsm_state_o       (fsm_state),
        .pfi_warn_o        (pfi_warn_internal),
        .shdn_req_o        (shdn_req_internal),
        .status_led_o      (status_led_o)
    );

endmodule
