/*
 * Copyright (c) 2024 Michael Ma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_uwasic_onboarding_michael_ma (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // 1. Set all 8 uio pins to output mode
  wire COPI;
  wire nCS;
  wire SCLK;
  assign COPI = ui_in[1];
  assign nCS = ui_in[2];
  assign SCLK = ui_in[0];
  assign uio_oe = 8'hFF; 
  // NOTE: The old template lines (assign uo_out = ui_in + uio_in; assign uio_out = 0;) 
  // have been REMOVED. If left in, they would cause a "multiple driver" compilation 
  // error because the pwm_peripheral_inst below is also driving these outputs.

  // 2. Wires to connect to the PWM peripheral
  // ⚠️ IMPORTANT: Check your pwm_peripheral.v file. 
  // If these are declared as `input` in the peripheral, you MUST assign them 
  // values here (e.g., assign en_reg_pwm_7_0 = 8'h00;). 
  // If they are `output` from the peripheral, leaving them as unassigned wires is fine.
  wire [7:0] en_reg_out_7_0;
  wire [7:0] en_reg_out_15_8;
  wire [7:0] en_reg_pwm_7_0;
  wire [7:0] en_reg_pwm_15_8;
  wire [7:0] pwm_duty_cycle;

  spi_peripheral_module spi_peripheral (
    .clk(clk),
    .rst_n(rst_n),
    .COPI(COPI),
    .nCS(nCS),
    .SCLK(SCLK),
    .en_reg_out_7_0(en_reg_out_7_0),
    .en_reg_out_15_8(en_reg_out_15_8),
    .en_reg_pwm_7_0(en_reg_pwm_7_0),
    .en_reg_pwm_15_8(en_reg_pwm_15_8),
    .pwm_duty_cycle(pwm_duty_cycle)
  );
  // 3. Instantiate the PWM module
  pwm_peripheral pwm_peripheral_inst (
    .clk(clk),
    .rst_n(rst_n),
    .en_reg_out_7_0(en_reg_out_7_0),
    .en_reg_out_15_8(en_reg_out_15_8),
    .en_reg_pwm_7_0(en_reg_pwm_7_0),
    .en_reg_pwm_15_8(en_reg_pwm_15_8),
    .pwm_duty_cycle(pwm_duty_cycle),
    .out({uio_out, uo_out}) // Concatenation: {uio_out[7:0], uo_out[7:0]} = 16 bits total
  );

  // 4. List all unused inputs to prevent linter/synthesis warnings
  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule

