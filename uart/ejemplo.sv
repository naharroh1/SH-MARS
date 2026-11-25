/**
 * File              : ejemplo.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 07.04.2025
 * Last Modified Date: 07.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module ejemplo (
    input clk,
    input rst,
    input rx,
    output tx,
    inout bus_data,
    output rx_tmp,
    output [7:0] data
);

  assign rx_tmp = 1'bz;

  logic cpu_rx;
  logic cpu_tx;
  logic cpu_tx_start;
  logic [7:0] cpu_byte_tx;
  logic [7:0] cpu_byte_rx;
  logic cpu_rx_active;
  logic cpu_tx_active;
  logic cpu_tx_done;
  logic cpu_rx_done;
  logic [3:0] cpu_estado_rx;
  logic [3:0] cpu_estado_tx;

  logic servo_bus_data;
  logic [7:0] servo_rx_data;
  logic [7:0] servo_tx_data;
  logic servo_tx_start;
  logic servo_tx_done;
  logic servo_rx_done;
  logic servo_tx_active;
  logic servo_rx_active;
  logic servo_rx_debug;
  logic servo_tx_debug;

  assign cpu_tx = tx;
  assign cpu_rx = rx;
  assign servo_bus_data = bus_data;
  assign cpu_tx_start = servo_rx_done;
  assign servo_tx_start = cpu_rx_done;
  assign cpu_byte_tx = servo_rx_data;
  assign servo_tx_data = cpu_byte_rx;

      ila_0 ila (
          .clk(clk),
          .probe0(cpu_rx),
          .probe1(servo_tx_debug),
          .probe2(cpu_tx),
          .probe3(servo_rx_debug),
          .probe4(cpu_rx_done),
          .probe5(servo_tx_done),
          .probe6(cpu_tx_start),
          .probe7(servo_tx_start),
          .probe8(cpu_tx_done),
          .probe9(servo_rx_done),
          .probe10(cpu_rx_active),
          .probe11(cpu_tx_active),
          .probe12(servo_rx_active),
          .probe13(servo_tx_active),
          .probe14(servo_rx_data),
         .probe15(servo_tx_data)
      );


  uart uart_cpu (
      .clk(clk),
      .rst(rst),
      .rx(cpu_rx),
      .tx(cpu_tx),
      .tx_start(cpu_tx_start),
      .byte_tx(cpu_byte_tx),
      .byte_rx(cpu_byte_rx),
      .rx_active(cpu_rx_active),
      .tx_active(cpu_tx_active),
      .tx_done(cpu_tx_done),
      .rx_done(cpu_rx_done),
      .estado_rx(cpu_estado_rx),
      .estado_tx(cpu_estado_tx)
  );

  uart_half_duplex uart_servo (
      .clk(clk),
      .rst(rst),
      .bus_data(servo_bus_data),
      .rx_data(servo_rx_data),
      .tx_data(servo_tx_data),
      .tx_start(servo_tx_start),
      .tx_done(servo_tx_done),
      .rx_done(servo_rx_done),
      .tx_active(servo_tx_active),
      .rx_active(servo_rx_active),
      .rx_debug(servo_rx_debug),
      .tx_debug(servo_tx_debug)
  );

  /*
  uart_half_duplex_fifo uart_inst (
      .clk(clk),
      .rst(rst),
      .bus_data(servo_bus_data),
      .data_rx(servo_rx_data),
      .byte_tx(servo_tx_data),
      .tx_start(servo_tx_start),
      .rx_empty(),
      .tx_empty(),
      .rx_full(),
      .tx_full(),
      .rx_bytes_available(rx_bytes_available),
      .rx_active(servo_rx_active),
      .tx_active(servo_tx_active),
      .read_byte(),
      .debug_pop_tx(),
      .debug_data_tx()
  );
  */
endmodule

