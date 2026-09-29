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
wire SCLK_rising = SCLK_s1 & !SCLK_s2;

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