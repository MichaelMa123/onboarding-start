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

module spi_peripheral_module (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       COPI,
    input  wire       nCS,
    input  wire       SCLK,
    output reg [7:0]  en_reg_out_7_0,
    output reg [7:0]  en_reg_out_15_8,
    output reg [7:0]  en_reg_pwm_7_0,
    output reg [7:0]  en_reg_pwm_15_8,
    output reg [7:0]  pwm_duty_cycle
);

  reg [15:0] spi_shift_reg;
  reg [4:0]  counter;
  reg nCS_s1,  nCS_s2;
  reg SCLK_s1, SCLK_s2;
  reg COPI_s1, COPI_s2;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    nCS_s1  <= 1'b1; nCS_s2  <= 1'b1;
    SCLK_s1 <= 1'b0; SCLK_s2 <= 1'b0;
    COPI_s1 <= 1'b0; COPI_s2 <= 1'b0;
  end else begin
    nCS_s1  <= nCS;  nCS_s2  <= nCS_s1;
    SCLK_s1 <= SCLK; SCLK_s2 <= SCLK_s1;
    COPI_s1 <= COPI; COPI_s2 <= COPI_s1;
  end
end

wire nCS_rising  = !nCS_s2 & nCS_s1;
wire SCLK_rising = SCLK_s2 & !SCLK_s1;

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    spi_shift_reg <= 16'b0;
    counter <= 5'b0;
  end else begin
    if (nCS_rising) begin
      counter       <= 5'b0;
      spi_shift_reg <= 16'b0;
    end 
    else if (SCLK_rising && !nCS_s2) begin
      spi_shift_reg <= {spi_shift_reg[14:0], COPI_s2};
      counter <= counter + 1'b1;
    end
  end
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    en_reg_out_7_0   <= 8'h00;
    en_reg_out_15_8  <= 8'h00;
    en_reg_pwm_7_0   <= 8'h00;
    en_reg_pwm_15_8  <= 8'h00;
    pwm_duty_cycle   <= 8'h00;
  end else begin
    if(nCS_rising && counter== 5'd16) begin
      case(spi_shift_reg[15])
        1'b1:
          case(spi_shift_reg[14:8])
            7'h00:
              en_reg_out_7_0 <= spi_shift_reg[7:0];
            7'h01:
              en_reg_out_15_8 <= spi_shift_reg[7:0];
            7'h02:
              en_reg_pwm_7_0 <= spi_shift_reg[7:0];
            7'h03:
              en_reg_pwm_15_8 <= spi_shift_reg[7:0];
            7'h04:
              pwm_duty_cycle <= spi_shift_reg[7:0];
            default:;
          endcase
        default:;
      endcase
    end
  end
end

endmodule