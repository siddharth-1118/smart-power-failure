// ============================================================================
// File: spf_defines.vh
// Project: Smart Power-Failure Predictor ASIC
// Description: Global parameter definitions, register addresses, and FSM states
// ============================================================================

`ifndef SPF_DEFINES_VH
`define SPF_DEFINES_VH

// Register Address Map (4-bit word address)
`define ADDR_CTRL_REG      4'h0
`define ADDR_V_WARN_THRESH 4'h1
`define ADDR_V_CRIT_THRESH 4'h2
`define ADDR_SLOPE_THRESH  4'h3
`define ADDR_HYST_THRESH   4'h4
`define ADDR_STATUS_REG    4'h5
`define ADDR_INT_CLEAR     4'h6
`define ADDR_VOLT_LATCH    4'h7

// Default Reset Threshold Values (12-bit ADC full-scale: 0 to 4095 mV / counts)
// Assuming 1 LSB = 1 mV (0 to 4.095V dynamic range):
`define DEFAULT_V_WARN     12'd2900  // 2.90V Warning threshold
`define DEFAULT_V_CRIT     12'd2600  // 2.60V Critical panic threshold
`define DEFAULT_SLOPE      12'd50    // 50 mV / sample max allowed drop rate
`define DEFAULT_HYST       12'd100   // 100 mV recovery hysteresis (3.00V to recover)

// FSM State Encoding (3-bit Gray / Binary)
`define FSM_RESET          3'b000
`define FSM_NORMAL         3'b001
`define FSM_SAG_DETECT     3'b010
`define FSM_EARLY_WARNING  3'b011
`define FSM_PANIC_SHUTDOWN 3'b100
`define FSM_RECOVERY       3'b101

// Control Register Bit Mapping
`define CTRL_ENABLE_BIT    0
`define CTRL_SLOPE_EN_BIT  1
`define CTRL_FILTER_EN_BIT 2
`define CTRL_AUTO_REC_BIT  3

`endif // SPF_DEFINES_VH
