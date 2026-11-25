/**
 * File              : uart.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 04.04.2025
 * Last Modified Date: 04.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */

module uart #(
    parameter F_MHZ   = 100,
    parameter BAUDIOS = 1000000
) (
    input clk,
    input rst,
    input rx,
    output tx,
    input tx_start,
    input [7:0] byte_tx,
    output [7:0] byte_rx,
    output rx_active,
    output tx_active,
    output tx_done,
    output rx_done,
    output [2:0] estado_rx,
    output [2:0] estado_tx
);

  UART_RX #(
      .F_MHZ  (F_MHZ),
      .BAUDIOS(BAUDIOS)
  ) recep (
      .clk(clk),
      .rst(rst),
      .rx(rx),
      .rx_done(rx_done),
      .active(rx_active),
      .estado(estado_rx),
      .rx_byte(byte_rx)
  );

  UART_TX #(
      .F_MHZ  (F_MHZ),
      .BAUDIOS(BAUDIOS)
  ) trans (
      .clk(clk),
      .rst(rst),
      .start(tx_start),
      .byte_in(byte_tx),
      .estado(estado_tx),
      .active(tx_active),
      .tx(tx),
      .done(tx_done)
  );

endmodule
