@echo off
echo ==============================================================================
echo [1/4] Running Functional RTL Simulation (Icarus Verilog + VVP)...
echo ==============================================================================
wsl -d Ubuntu-22.04 bash -c "cd /mnt/e/projects/'smart power failure' && iverilog -I rtl -o sim/spf_sim.vvp rtl/spf_defines.vh rtl/spf_reg_bank.v rtl/spf_trend_engine.v rtl/spf_slope_calc.v rtl/spf_fsm.v rtl/spf_predictor_top.v tb/spf_predictor_tb.v && vvp sim/spf_sim.vvp"

echo.
echo ==============================================================================
echo [2/4] Running Gate-Level Logic Synthesis (Yosys Open SYnthesis Suite)...
echo ==============================================================================
wsl -d Ubuntu-22.04 bash -c "cd /mnt/e/projects/'smart power failure' && yosys -s syn/synth.ys | tee reports/synthesis_report.log"

echo.
echo ==============================================================================
echo [3/4] Generating Physical Tapeout Layout & GDSII Mask...
echo ==============================================================================
python pnr/generate_tapeout_layout.py
python pnr/audit_gds.py

echo.
echo ==============================================================================
echo [4/4] Updating Final Comprehensive Lab Report PDF...
echo ==============================================================================
python generate_final_report_pdf.py

echo.
echo ==============================================================================
echo >>> FULL RTL-TO-TAPEOUT FLOW EXECUTED SUCCESSFULLY ON E: DRIVE! <<<
echo ==============================================================================
pause
