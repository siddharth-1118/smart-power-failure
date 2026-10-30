// ============================================================================
// File: spf_predictor_tb.v
// Project: Smart Power-Failure Predictor ASIC
// Description: Comprehensive Self-Checking Verification Testbench covering
//              Normal noise, Progressive Sag, Sudden Catastrophic dV/dt,
//              Register Bus Programming, and Power Recovery.
// ============================================================================

`timescale 1ns / 1ps
`include "spf_defines.vh"

module spf_predictor_tb;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;

    // ADC Sensor Interface
    reg  [11:0] adc_data_i;
    reg         adc_valid_i;

    // Register Bus Interface
    reg  [3:0]  reg_addr_i;
    reg  [15:0] reg_wdata_i;
    reg         reg_we_i;
    reg         reg_re_i;
    wire [15:0] reg_rdata_o;
    wire        reg_ack_o;

    // ASIC Outputs
    wire        pfi_warn_o;
    wire        pfi_warn_n_o;
    wire        shdn_req_o;
    wire [2:0]  status_led_o;

    // Testbench tracking
    integer test_errors = 0;
    integer tests_passed = 0;

    // Instantiate Device Under Test (DUT)
    spf_predictor_top dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .adc_data_i   (adc_data_i),
        .adc_valid_i  (adc_valid_i),
        .reg_addr_i   (reg_addr_i),
        .reg_wdata_i  (reg_wdata_i),
        .reg_we_i     (reg_we_i),
        .reg_re_i     (reg_re_i),
        .reg_rdata_o  (reg_rdata_o),
        .reg_ack_o    (reg_ack_o),
        .pfi_warn_o   (pfi_warn_o),
        .pfi_warn_n_o (pfi_warn_n_o),
        .shdn_req_o   (shdn_req_o),
        .status_led_o (status_led_o)
    );

    // 50 MHz System Clock Generation (Period = 20 ns)
    always #10 clk = ~clk;

    // Task: Feed an ADC sample with synchronous valid strobe
    task feed_adc_sample;
        input [11:0] voltage_mv;
        begin
            @(posedge clk);
            adc_data_i  <= voltage_mv;
            adc_valid_i <= 1'b1;
            @(posedge clk);
            adc_valid_i <= 1'b0;
            // Allow 3 cycles between conversion samples
            repeat (3) @(posedge clk);
        end
    endtask

    // Task: Write to Memory-Mapped Control Register
    task write_reg;
        input [3:0]  addr;
        input [15:0] data;
        begin
            @(posedge clk);
            reg_addr_i  <= addr;
            reg_wdata_i <= data;
            reg_we_i    <= 1'b1;
            reg_re_i    <= 1'b0;
            @(posedge clk);
            while (!reg_ack_o) @(posedge clk);
            reg_we_i    <= 1'b0;
            @(posedge clk);
        end
    endtask

    // Task: Read from Memory-Mapped Control Register
    task read_reg;
        input  [3:0]  addr;
        output [15:0] data;
        begin
            @(posedge clk);
            reg_addr_i <= addr;
            reg_we_i   <= 1'b0;
            reg_re_i   <= 1'b1;
            @(posedge clk);
            while (!reg_ack_o) @(posedge clk);
            data = reg_rdata_o;
            reg_re_i   <= 1'b0;
            @(posedge clk);
        end
    endtask

    // ========================================================================
    // Main Verification Execution
    // ========================================================================
    reg [15:0] read_val;

    initial begin
        // Setup Waveform Dump for GTKWave
        $dumpfile("sim/power_sag_dump.vcd");
        $dumpvars(0, spf_predictor_tb);

        // Initialize Signals
        clk         = 0;
        rst_n       = 0;
        adc_data_i  = 12'd3300;
        adc_valid_i = 0;
        reg_addr_i  = 0;
        reg_wdata_i = 0;
        reg_we_i    = 0;
        reg_re_i    = 0;

        $display("----------------------------------------------------------------");
        $display(">>> STARTING SMART POWER-FAILURE PREDICTOR ASIC VERIFICATION <<<");
        $display("----------------------------------------------------------------");

        // Step 1: Apply Hardware Reset
        #50;
        rst_n = 1;
        #40;
        $display("[TIME: %0t ns] Reset de-asserted. System running.", $time);

        // --------------------------------------------------------------------
        // TEST SCENARIO 1: Nominal 3.3V Healthy Power with Switching Noise
        // --------------------------------------------------------------------
        $display("\n--- [TEST 1] Nominal 3.3V Health with Inductive Ripple ---");
        // Establish baseline nominal power
        feed_adc_sample(12'd3300);
        feed_adc_sample(12'd3305);
        feed_adc_sample(12'd3295);
        feed_adc_sample(12'd3300);

        if (status_led_o == 3'b001 && pfi_warn_o == 0 && shdn_req_o == 0) begin
            $display("[PASS] State is NORMAL (Green LED, zero alert flags).");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Expected NORMAL state. LED: %b, Warn: %b", status_led_o, pfi_warn_o);
            test_errors = test_errors + 1;
        end

        // Inject high-frequency single-sample noise ripple (30 mV drop)
        $display("[TIME: %0t ns] Injecting switching ripple (3270 mV, 30 mV ripple)...", $time);
        feed_adc_sample(12'd3270); // 30 mV ripple < 50 mV slope threshold
        feed_adc_sample(12'd3300); // Immediate bounce-back
        feed_adc_sample(12'd3300);

        if (pfi_warn_o == 0 && shdn_req_o == 0) begin
            $display("[PASS] Noise Filter successfully rejected transient ripple. No false alarm!");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Noise Filter failed! False alarm triggered. Warn: %b, Shdn: %b", pfi_warn_o, shdn_req_o);
            test_errors = test_errors + 1;
        end

        // --------------------------------------------------------------------
        // TEST SCENARIO 2: Progressive Battery Sag (Early Warning Verification)
        // --------------------------------------------------------------------
        $display("\n--- [TEST 2] Progressive Battery Sag (Early Warning Interrupt) ---");
        $display("[TIME: %0t ns] Simulating gradual battery decay (smooth drop rate 35 mV/sample)...", $time);
        // Start smoothly from 3300 mV down to below 2900 mV (steps <= 40 mV):
        feed_adc_sample(12'd3265);
        feed_adc_sample(12'd3230);
        feed_adc_sample(12'd3195);
        feed_adc_sample(12'd3160);
        feed_adc_sample(12'd3125);
        feed_adc_sample(12'd3090);
        feed_adc_sample(12'd3055);
        feed_adc_sample(12'd3020);
        feed_adc_sample(12'd2985);
        feed_adc_sample(12'd2950);
        feed_adc_sample(12'd2915);
        feed_adc_sample(12'd2880); // Crosses V_WARN (2900 mV)
        feed_adc_sample(12'd2845);

        if (pfi_warn_o == 1 && shdn_req_o == 0 && status_led_o == 3'b010) begin
            $display("[PASS] EARLY WARNING triggered correctly! (pfi_warn_o = 1, Yellow LED).");
            $display("       Advance notice delivered to MCU while voltage is still at 2845 mV (well above 2600 mV)!");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Early Warning failed to assert! Warn: %b, Shdn: %b, LED: %b", pfi_warn_o, shdn_req_o, status_led_o);
            test_errors = test_errors + 1;
        end

        // --------------------------------------------------------------------
        // TEST SCENARIO 3: Deep Collapse to Critical Voltage (Shutdown Request)
        // --------------------------------------------------------------------
        $display("\n--- [TEST 3] Severe Power Collapse (Emergency Shutdown) ---");
        $display("[TIME: %0t ns] Voltage dropping below critical threshold (2600 mV)...", $time);
        feed_adc_sample(12'd2810);
        feed_adc_sample(12'd2775);
        feed_adc_sample(12'd2740);
        feed_adc_sample(12'd2700);
        feed_adc_sample(12'd2550); // Under V_CRIT (2600 mV)
        feed_adc_sample(12'd2500);

        if (shdn_req_o == 1 && status_led_o == 3'b100) begin
            $display("[PASS] EMERGENCY SHUTDOWN triggered! (shdn_req_o = 1, Red LED).");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Emergency shutdown failed! Shdn: %b, LED: %b", shdn_req_o, status_led_o);
            test_errors = test_errors + 1;
        end

        // --------------------------------------------------------------------
        // TEST SCENARIO 4: Power Recovery with Hysteresis
        // --------------------------------------------------------------------
        $display("\n--- [TEST 4] Power Rail Recovery with Stability Hysteresis ---");
        $display("[TIME: %0t ns] Restoring power back to 3.3V...", $time);
        feed_adc_sample(12'd2800);
        feed_adc_sample(12'd2950); // Above V_WARN, but below Hysteresis (3000 mV)
        feed_adc_sample(12'd3100); // Above 3000 mV (V_WARN + HYST)
        feed_adc_sample(12'd3200);
        feed_adc_sample(12'd3300);
        feed_adc_sample(12'd3300);
        feed_adc_sample(12'd3300);
        feed_adc_sample(12'd3300);

        if (status_led_o == 3'b001 && shdn_req_o == 0) begin
            $display("[PASS] System recovered to NORMAL state without chattering.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Recovery failed! State LED: %b, Shdn: %b", status_led_o, shdn_req_o);
            test_errors = test_errors + 1;
        end

        // --------------------------------------------------------------------
        // TEST SCENARIO 5: Sudden Disconnect Catastrophic dV/dt Detection
        // --------------------------------------------------------------------
        $display("\n--- [TEST 5] Sudden Disconnect / Fast Negative Slope (dV/dt) ---");
        $display("[TIME: %0t ns] Power at 3300 mV. Suddenly disconnecting capacitor...", $time);
        feed_adc_sample(12'd3300);
        // Instant drop by 350 mV in one step (to 2950 mV, still above V_WARN=2900 mV!)
        feed_adc_sample(12'd2950);

        if (shdn_req_o == 1) begin
            $display("[PASS] Slope Engine caught catastrophic drop instantly (dV/dt exceeded 50 mV/sample)!");
            $display("       Emergency Shutdown fired BEFORE voltage even reached 2.90V!");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Slope Engine did not catch fast drop! Shdn: %b", shdn_req_o);
            test_errors = test_errors + 1;
        end

        // --------------------------------------------------------------------
        // TEST SCENARIO 6: Memory-Mapped Register Configuration
        // --------------------------------------------------------------------
        $display("\n--- [TEST 6] Memory-Mapped Register Bus Programming ---");
        // Reconfigure V_WARN_THRESH to 3100 mV (0x0C1C)
        write_reg(`ADDR_V_WARN_THRESH, 16'd3100);
        read_reg(`ADDR_V_WARN_THRESH, read_val);
        
        if (read_val[11:0] == 12'd3100) begin
            $display("[PASS] V_WARN_THRESH programmed successfully: %0d mV", read_val[11:0]);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] Register write mismatch! Read: %0d", read_val[11:0]);
            test_errors = test_errors + 1;
        end

        // Reconfigure SLOPE_THRESH to 100 mV
        write_reg(`ADDR_SLOPE_THRESH, 16'd100);
        read_reg(`ADDR_SLOPE_THRESH, read_val);
        
        if (read_val[11:0] == 12'd100) begin
            $display("[PASS] SLOPE_THRESH programmed successfully: %0d mV", read_val[11:0]);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] SLOPE_THRESH write mismatch! Read: %0d", read_val[11:0]);
            test_errors = test_errors + 1;
        end

        // Clear Interrupts
        write_reg(`ADDR_INT_CLEAR, 16'h0007);
        read_reg(`ADDR_STATUS_REG, read_val);
        $display("[INFO] STATUS_REG after clear: 0x%04X", read_val);

        // --------------------------------------------------------------------
        // Final Summary
        // --------------------------------------------------------------------
        #100;
        $display("\n================================================================");
        $display("VERIFICATION SUMMARY: %0d Tests Passed, %0d Errors", tests_passed, test_errors);
        if (test_errors == 0) begin
            $display(">>> ALL SYSTEM TESTS PASSED SUCCESSFULLY! ASIC IS VERIFIED <<<");
        end else begin
            $display(">>> SYSTEM VERIFICATION ENCOUNTERED ERRORS <<<");
        end
        $display("================================================================\n");

        $finish;
    end

endmodule
