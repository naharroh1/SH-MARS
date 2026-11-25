/**
 * File              : top.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 09.04.2025
 * Last Modified Date: 09.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */

module top #(
    parameter F_MHZ = 100,
    parameter BAUDIOS = 1000000,
    parameter UART_FIFO_DEPTH = 16,
    parameter UART_WB_ADDR_SIZE = 32,
    parameter UART_WB_ADDR = 32'h400,
    parameter SDSPI_WB_ADDR_SIZE = 32,
    parameter SDSPI_WB_ADDR = 32'h200,
    parameter WB_DATA = 32
) (
    input clk,
    input rst,

    //ctrl_dynamixel
    input  start_ctrl,
    output err_ctrl,
    //    input [4:0] sclk_speed,
    //   input [2:0] base_addr_for_inst,

    //sdspi
    input  miso,
    output mosi,
    output sclk,
    output ss,
    output SD_RESET,
    output SD_DAT_1,
    output SD_DAT_2,

    //uart_half_duplex
    inout  bus_data,
    input  rx,
    output tx

);

  logic wb_rst;
  assign wb_rst = rst;

  logic [7:0] ctrl_state;
  logic [7:0] sdspi_state;
  logic [7:0] uart_state;
  logic [31:0] sdspi_debug;
  logic debug_rx_active;
  logic debug_tx_active;
  logic debug_rx_full;
  logic debug_tx_full;
  logic debug_tx_empty;
  logic debug_rx_empty;
  logic debug_pop_tx;
  logic [7:0] debug_data_tx;
  logic [7:0] debug_data_rx;
  logic [7:0] debug_byte_rx;
  logic [7:0] debug_byte_tx;
  logic [31:0] debug_r_wb_dat_i_dout;
  logic [31:0] debug_counter_inst;
  logic debug_start_tx;
  //SD in SPI_MODE
  assign SD_RESET = 1'b0;
  assign SD_DAT_1 = 1'b1;
  assign SD_DAT_2 = 1'b1;

  `include "wb_intercon_top.vh"

ila_0 ila (
      .clk(clk),
      .probe0({
        debug_rx_active,
        debug_tx_active,
        debug_rx_full,
        debug_tx_empty,
        debug_pop_tx,
        debug_start_tx
      }),
      .probe1(debug_counter_inst),
      .probe2({sdspi_state, ctrl_state, uart_state}),
      .probe3(wb_ctrl_dat),
      .probe4({debug_byte_rx, debug_data_rx, debug_byte_tx, debug_data_tx}),
      .probe5(wb_sdspi_rdt),
      .probe6(debug_r_wb_dat_i_dout),
      .probe7(wb_ctrl_rdt),
      .probe8(wb_uart_rdt),
      .probe9(wb_ctrl_dat),
      .probe10(wb_uart_dat)
  );

  /*
  uart_wb #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .FIFO_DEPTH(UART_FIFO_DEPTH),
      .WB_ADDR_DIR(UART_WB_ADDR_SIZE),
        .WB_DATA_WIDTH(WB_DATA)
  ) uart_inst (
      .wb_clk(clk),
      .wb_rst(wb_rst || rst),
      .rx(rx),
      .tx(tx),

      .wb_adr_i(wb_uart_adr),
      .wb_dat_i(wb_uart_dat),
      .wb_we_i(wb_uart_we),
      .wb_cyc_i(wb_uart_cyc),
      .wb_stb_i(wb_uart_stb),
      .wb_sel_i(wb_uart_sel),
      .wb_cti_i(wb_uart_cti),
      .wb_bte_i(wb_uart_bte),
      .wb_ack_o(wb_uart_ack),
      .wb_err_o(wb_uart_err),
      .wb_rty_o(wb_uart_rty),
      .wb_dat_o(wb_uart_rdt),
      .debug_state(uart_state),
      .debug_tx_active(debug_tx_active),
      .debug_rx_active(debug_rx_active),
      .debug_tx_empty(debug_tx_empty),
      .debug_rx_empty(debug_rx_empty),
      .debug_tx_full(debug_tx_full),
      .debug_rx_full(debug_rx_full),
      .debug_data_tx(debug_data_tx),
      .debug_pop_tx(debug_pop_tx)
  );
*/
  uart_half_duplex_wb #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .FIFO_DEPTH(UART_FIFO_DEPTH),
      .WB_ADDR_DIR(UART_WB_ADDR_SIZE),
      .WB_DATA_WIDTH(WB_DATA)
  ) uart_inst (
      .wb_clk  (clk),
      .wb_rst  (wb_rst || rst),
      .bus_data(bus_data),

      .wb_adr_i(wb_uart_adr),
      .wb_dat_i(wb_uart_dat),
      .wb_we_i(wb_uart_we),
      .wb_cyc_i(wb_uart_cyc),
      .wb_stb_i(wb_uart_stb),
      .wb_sel_i(wb_uart_sel),
      .wb_cti_i(wb_uart_cti),
      .wb_bte_i(wb_uart_bte),
      .wb_ack_o(wb_uart_ack),
      .wb_err_o(wb_uart_err),
      .wb_rty_o(wb_uart_rty),
      .wb_dat_o(wb_uart_rdt),
      .debug_state(uart_state),
      .debug_tx_active(debug_tx_active),
      .debug_rx_active(debug_rx_active),
      .debug_tx_empty(debug_tx_empty),
      .debug_rx_empty(debug_rx_empty),
      .debug_tx_full(debug_tx_full),
      .debug_rx_full(debug_rx_full),
      .debug_data_tx(debug_data_tx),
      .debug_pop_tx(debug_pop_tx),
      .debug_data_rx(debug_data_rx),
      .debug_byte_rx(debug_byte_rx),
      .debug_byte_tx(debug_byte_tx),
      .debug_start_tx(debug_start_tx)
  );
  sdspi_wb #(
      .CLK_FQ_KHZ(F_MHZ * 1000),
      .WB_ADDR_DIR(SDSPI_WB_ADDR_SIZE),
      .WB_DATA_WIDTH(WB_DATA)
  ) sdspi_inst (
      .wb_clk(clk),
      .wb_rst(wb_rst || rst),
      .miso(miso),
      .mosi(mosi),
      .sclk(sclk),
      .ss(ss),

      .wb_adr_i(wb_sdspi_adr),
      .wb_dat_i(wb_sdspi_dat),
      .wb_we_i(wb_sdspi_we),
      .wb_cyc_i(wb_sdspi_cyc),
      .wb_stb_i(wb_sdspi_stb),
      .wb_sel_i(wb_sdspi_sel),
      .wb_cti_i(wb_sdspi_cti),
      .wb_bte_i(wb_sdspi_bte),
      .wb_ack_o(wb_sdspi_ack),
      .wb_err_o(wb_sdspi_err),
      .wb_rty_o(wb_sdspi_rty),
      .wb_dat_o(wb_sdspi_rdt),
      .debug_state(sdspi_state),
      .sdspi_debug(sdspi_debug)
  );

  ctrl_dynamixel #(
      .WB_DATA(WB_DATA),
      .UART_WB_ADDR(UART_WB_ADDR),
      .SDSPI_WB_ADDR(SDSPI_WB_ADDR)
  ) ctrl_inst (
      .wb_clk(clk),
      .rst(rst),
      .start(start_ctrl),
      .err(err_ctrl),
      .sclk_speed(3'h01  /*sclk_speed*/),
      .base_addr_for_inst(8'h0  /*base_addr_for_inst*/),

      .wb_rst_o(),
      .wb_ack_i(wb_ctrl_ack),
      .wb_err_i(wb_ctrl_err),
      .wb_dat_i(wb_ctrl_rdt),
      .wb_rty_i(wb_ctrl_rty),
      .wb_dat_o(wb_ctrl_dat),
      .wb_cyc_o(wb_ctrl_cyc),
      .wb_stb_o(wb_ctrl_stb),
      .wb_sel_o(wb_ctrl_sel),
      .wb_we_o(wb_ctrl_we),
      .wb_cti_o(wb_ctrl_cti),
      .wb_bte_o(wb_ctrl_bte),
      .wb_adr_o(wb_ctrl_adr),
      .debug_state(ctrl_state),
      .debug_r_wb_dat_i_dout(debug_r_wb_dat_i_dout),
      .debug_counter_inst(debug_counter_inst)
  );

endmodule
