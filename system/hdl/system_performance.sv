/**
 * File              : system_performance.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 06.06.2025
 * Last Modified Date: 06.06.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module system_performance #(
    parameter F_MHZ = 100,
    parameter BAUDIOS = 1000000,
    parameter TOP_UART_FIFO_DEPTH = 16,
    parameter TOP_UART_WB_ADDR_SIZE = 32,
    parameter TOP_UART_WB_ADDR = 32'h400,
    parameter TOP_SDSPI_WB_ADDR_SIZE = 32,
    parameter TOP_SDSPI_WB_ADDR = 32'h200,
    parameter TOP_WB_DATA = 32,
    parameter MITM_UART_FIFO_DEPTH = 16,
    parameter MITM_UART_CAPTURER_WB_ADDR_SIZE = 32,
    parameter MITM_UART_CAPTURER_WB_ADDR = 32'h600,
    parameter MITM_UART_SERVO_WB_ADDR_SIZE = 32,
    parameter MITM_UART_SERVO_WB_ADDR = 32'h800,
    parameter MITM_IMPOSTOR_WB_ADDR_SIZE = 32,
    parameter MITM_IMPOSTOR_WB_ADDR = 32'hA00,
    parameter MITM_SHAPER_WB_ADDR_SIZE = 32,
    parameter MITM_SHAPER_WB_ADDR = 32'hC00,
    parameter MITM_MAX_NUM_PARAMETERS_ALLOWED = 8,
    parameter MITM_FILE_MEM = "memory.mem",
    parameter MITM_SHAPER_FILE_MEM = "memory_shaper.mem",
    parameter MITM_WB_DATA = 32


) (
    input clk,
    input rst,

    input start_ctrl,
    output err_ctrl,
    input [4:0] sclk_speed,
    input [2:0] base_addr_for_inst,

    input  miso,
    output mosi,
    output sclk,
    output ss,
    output SD_RESET,
    output SD_DAT_1,
    output SD_DAT_2,

    output [3:0] an,
    output [6:0] seg,
    output end_signal,

    inout bus_data_servo,
    inout bus_data_system,
    inout bus_data_capturer,
    input rx_system,
    output tx_system,
    input rx_capturer,
    output tx_capturer,
    input [15:0] switches,
    input right_button
);

  logic bus_data;

  top #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .UART_FIFO_DEPTH(TOP_UART_FIFO_DEPTH),
      .UART_WB_ADDR_SIZE(TOP_UART_WB_ADDR_SIZE),
      .UART_WB_ADDR(TOP_UART_WB_ADDR),
      .SDSPI_WB_ADDR_SIZE(TOP_SDSPI_WB_ADDR_SIZE),
      .SDSPI_WB_ADDR(TOP_SDSPI_WB_ADDR),
      .WB_DATA(TOP_WB_DATA)
  ) top_dyn (
      .clk(clk),
      .rst(rst),
      .start_ctrl(start_ctrl),
      .err_ctrl(err_ctrl),
      .sclk_speed(5'h2),
      .base_addr_for_inst(3'h0),
      .miso(miso),
      .mosi(mosi),
      .sclk(sclk),
      .ss(ss),
      .SD_RESET(SD_RESET),
      .SD_DAT_1(SD_DAT_1),
      .SD_DAT_2(SD_DAT_2),
      .bus_data(bus_data_system),
      .rx(rx_system),
      .tx(tx_system),
      .an(an),
      .seg(seg),
      .end_signal(end_signal),
      .measure_with_fifo(switches[15])
  );

  top_attacker #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .UART_FIFO_DEPTH(MITM_UART_FIFO_DEPTH),
      .UART_CAPTURER_WB_ADDR_SIZE(MITM_UART_CAPTURER_WB_ADDR_SIZE),
      .UART_SERVO_WB_ADDR_SIZE(MITM_UART_SERVO_WB_ADDR_SIZE),
      .UART_CAPTURER_WB_ADDR(MITM_UART_CAPTURER_WB_ADDR),
      .UART_SERVO_WB_ADDR(MITM_UART_SERVO_WB_ADDR),
      .IMPOSTOR_WB_ADDR_SIZE(MITM_IMPOSTOR_WB_ADDR_SIZE),
      .IMPOSTOR_WB_ADDR(MITM_IMPOSTOR_WB_ADDR),
      .SHAPER_WB_ADDR_SIZE(MITM_SHAPER_WB_ADDR_SIZE),
      .SHAPER_WB_ADDR(MITM_SHAPER_WB_ADDR),
      .MAX_NUM_PARAMETERS_ALLOWED(MITM_MAX_NUM_PARAMETERS_ALLOWED),
      .FILE_MEM(MITM_FILE_MEM),
      .SHAPER_FILE_MEM(MITM_SHAPER_FILE_MEM),
      .WB_DATA(MITM_WB_DATA)
  ) manInTheMiddle (
      .clk(clk),
      .rst(rst),
      .bus_data_servo(bus_data_servo),
      //.rx(rx_capturer),
      //.tx(tx_capturer),
      .bus_data_capturer(bus_data_capturer),
      .switches({0, switches[14:0]}),
      .right_button(right_button)
  );

endmodule
