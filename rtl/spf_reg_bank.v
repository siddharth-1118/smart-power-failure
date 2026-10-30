// ============================================================================
// File: spf_reg_bank.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Memory-Mapped Control & Status Registers (CSR)
// ============================================================================

`include "spf_defines.vh"

module spf_reg_bank (
    input  wire        clk,
    input  wire        rst_n,
    
    // Bus Interface
    input  wire [3:0]  reg_addr,
    input  wire [15:0] reg_wdata,
    input  wire        reg_we,
    input  wire        reg_re,
    output reg  [15:0] reg_rdata,
    output reg         reg_ack,
    
    // Status inputs from internal ASIC blocks
    input  wire [2:0]  fsm_state_i,
    input  wire        pfi_warn_active_i,
    input  wire        shdn_req_active_i,
    input  wire        slope_violation_i,
    input  wire [11:0] filtered_volt_i,
    
    // Control outputs to internal ASIC blocks
    output reg         ctrl_enable_o,
    output reg         ctrl_slope_en_o,
    output reg         ctrl_filter_en_o,
    output reg         ctrl_auto_recover_o,
    output reg  [11:0] v_warn_thresh_o,
    output reg  [11:0] v_crit_thresh_o,
    output reg  [11:0] slope_thresh_o,
    output reg  [11:0] hyst_thresh_o,
    output reg         int_clear_pulse_o
);

    // Internal sticky flags for status register
    reg sticky_warn;
    reg sticky_shdn;
    reg sticky_slope;

    // Synchronous Write & Reset Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_enable_o       <= 1'b1; // Enabled by default
            ctrl_slope_en_o     <= 1'b1; // Slope detection enabled by default
            ctrl_filter_en_o    <= 1'b1; // Filter enabled by default
            ctrl_auto_recover_o <= 1'b1; // Auto-recovery enabled by default
            v_warn_thresh_o     <= `DEFAULT_V_WARN;
            v_crit_thresh_o     <= `DEFAULT_V_CRIT;
            slope_thresh_o      <= `DEFAULT_SLOPE;
            hyst_thresh_o       <= `DEFAULT_HYST;
            int_clear_pulse_o   <= 1'b0;
            sticky_warn         <= 1'b0;
            sticky_shdn         <= 1'b0;
            sticky_slope        <= 1'b0;
            reg_ack             <= 1'b0;
        end else begin
            // Default pulse de-assertion
            int_clear_pulse_o   <= 1'b0;
            reg_ack             <= (reg_we | reg_re);

            // Update sticky interrupt flags
            if (pfi_warn_active_i) sticky_warn  <= 1'b1;
            if (shdn_req_active_i) sticky_shdn  <= 1'b1;
            if (slope_violation_i) sticky_slope <= 1'b1;

            // Handle Register Writes
            if (reg_we) begin
                case (reg_addr)
                    `ADDR_CTRL_REG: begin
                        ctrl_enable_o       <= reg_wdata[`CTRL_ENABLE_BIT];
                        ctrl_slope_en_o     <= reg_wdata[`CTRL_SLOPE_EN_BIT];
                        ctrl_filter_en_o    <= reg_wdata[`CTRL_FILTER_EN_BIT];
                        ctrl_auto_recover_o <= reg_wdata[`CTRL_AUTO_REC_BIT];
                    end
                    `ADDR_V_WARN_THRESH: begin
                        v_warn_thresh_o     <= reg_wdata[11:0];
                    end
                    `ADDR_V_CRIT_THRESH: begin
                        v_crit_thresh_o     <= reg_wdata[11:0];
                    end
                    `ADDR_SLOPE_THRESH: begin
                        slope_thresh_o      <= reg_wdata[11:0];
                    end
                    `ADDR_HYST_THRESH: begin
                        hyst_thresh_o       <= reg_wdata[11:0];
                    end
                    `ADDR_INT_CLEAR: begin
                        int_clear_pulse_o   <= 1'b1;
                        if (reg_wdata[0]) sticky_warn  <= 1'b0;
                        if (reg_wdata[1]) sticky_shdn  <= 1'b0;
                        if (reg_wdata[2]) sticky_slope <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end

    // Synchronous Read Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_rdata <= 16'h0000;
        end else if (reg_re) begin
            case (reg_addr)
                `ADDR_CTRL_REG: begin
                    reg_rdata <= {12'h0, ctrl_auto_recover_o, ctrl_filter_en_o, ctrl_slope_en_o, ctrl_enable_o};
                end
                `ADDR_V_WARN_THRESH: begin
                    reg_rdata <= {4'h0, v_warn_thresh_o};
                end
                `ADDR_V_CRIT_THRESH: begin
                    reg_rdata <= {4'h0, v_crit_thresh_o};
                end
                `ADDR_SLOPE_THRESH: begin
                    reg_rdata <= {4'h0, slope_thresh_o};
                end
                `ADDR_HYST_THRESH: begin
                    reg_rdata <= {4'h0, hyst_thresh_o};
                end
                `ADDR_STATUS_REG: begin
                    reg_rdata <= {
                        10'h0,
                        sticky_slope,        // bit 5: slope trip sticky
                        fsm_state_i,         // bits [4:2]: current FSM state
                        shdn_req_active_i,   // bit 1: live shutdown trigger
                        pfi_warn_active_i    // bit 0: live early warning
                    };
                end
                `ADDR_VOLT_LATCH: begin
                    reg_rdata <= {4'h0, filtered_volt_i};
                end
                default: begin
                    reg_rdata <= 16'hDEAD;
                end
            endcase
        end
    end

endmodule
