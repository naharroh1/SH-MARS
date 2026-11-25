/**
 * File              : top_attacker.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 25.04.2025
 * Last Modified Date: 25.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */

module top_attacker #(
    parameter F_MHZ = 100,
    parameter BAUDIOS = 1000000,
    parameter UART_FIFO_DEPTH = 16,
    parameter UART_CAPTURER_WB_ADDR_SIZE = 8,
    parameter UART_SERVO_WB_ADDR_SIZE = 8,
    parameter UART_CAPTURER_WB_ADDR = 32'h400,
    parameter UART_SERVO_WB_ADDR = 32'h800,
    parameter IMPOSTOR_WB_ADDR_SIZE = 8,
    parameter IMPOSTOR_WB_ADDR = 32'hA00,
    parameter SHAPER_WB_ADDR_SIZE = 8,
    parameter SHAPER_WB_ADDR = 32'h200,
    parameter MAX_NUM_PARAMETERS_ALLOWED = 8,
    parameter FILE_MEM = "memory.mem",
    parameter SHAPER_FILE_MEM = "memory_shaper.mem",
    parameter WB_DATA = 32
) (
    input clk,
    input rst,

    //uart_servo
    inout bus_data_servo,

    //uart_capturer
    inout bus_data_capturer,
    //input  rx,
    //output tx,

    //swicthes to change shaper mem
    input [15:0] switches,
    input right_button

);

  logic wb_rst;
  assign wb_rst = rst;


  `include "wb_intercon_mitm.vh"

  logic [5:0] ctrl_state;
  logic [2:0] servo_state;
  logic [4:0] impostor_state;
  logic [2:0]
      capturer_state, capturer_estado_tx, capturer_estado_rx, servo_estado_rx, servo_estado_tx;
  logic [7:0] shaper_state;
  logic [7:0]
      servo_data_tx,
      servo_data_rx,
      servo_byte_rx,
      capturer_data_tx,
      capturer_data_rx,
      capturer_byte_rx,
      impostor_checksum,
      impostor_bank_inst;



  //    ila_0 ila_inst_mitm (
  //        .clk(clk),
  //        .probe0({ctrl_state,servo_state,impostor_state,capturer_state,rx,tx}),
  //        .probe1({servo_data_tx,servo_data_rx,servo_byte_tx,servo_byte_rx}),
  //        .probe2(wb_mitm_ctrl_adr),
  //        .probe3(wb_mitm_ctrl_rdt),
  //        .probe4(wb_mitm_ctrl_dat),
  //        .probe5(wb_mitm_servo_adr),
  //        .probe6({capturer_data_tx,capturer_data_rx,capturer_byte_rx}),
  //        //.probe6(wb_mitm_shaper_rdt),
  //        .probe7({capturer_estado_tx,capturer_estado_rx,servo_estado_rx,servo_estado_tx})
  //    );
  //
  ctrl_attacker #(
      .WB_DATA(WB_DATA),
      .UART_SERVO_ADDR(UART_SERVO_WB_ADDR),
      .UART_CAPTURER_ADDR(UART_CAPTURER_WB_ADDR),
      .IMPOSTOR_ADDR(IMPOSTOR_WB_ADDR),
      .SHAPER_ADDR(SHAPER_WB_ADDR),
      .NUM_MODES(4)
  ) manInTheMiddle (
      .wb_clk(clk),
      .rst(rst),
      .wb_rst_o(),
      .wb_ack_i(wb_mitm_ctrl_ack),
      .wb_err_i(wb_mitm_ctrl_err),
      .wb_dat_i(wb_mitm_ctrl_rdt),
      .wb_rty_i(wb_mitm_ctrl_rty),
      .wb_dat_o(wb_mitm_ctrl_dat),
      .wb_cyc_o(wb_mitm_ctrl_cyc),
      .wb_stb_o(wb_mitm_ctrl_stb),
      .wb_sel_o(wb_mitm_ctrl_sel),
      .wb_we_o(wb_mitm_ctrl_we),
      .wb_cti_o(wb_mitm_ctrl_cti),
      .wb_bte_o(wb_mitm_ctrl_bte),
      .wb_adr_o(wb_mitm_ctrl_adr),
      .attack_mode(switches[1:0]),
      .trigger_mod_mem(right_button),
      .mem_shaper_addr(switches[7:2]),
      .mem_shaper_data(switches[15:8]),
      .debug_state(ctrl_state)
  );

  uart_half_duplex_wb #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .FIFO_DEPTH(UART_FIFO_DEPTH),
      .WB_ADDR_DIR(UART_SERVO_WB_ADDR_SIZE),
      .WB_DATA_WIDTH(WB_DATA)
  ) uart_servo (
      .wb_clk  (clk),
      .wb_rst  (wb_rst || rst),
      .bus_data(bus_data_servo),

      .wb_adr_i(wb_mitm_servo_adr),
      .wb_dat_i(wb_mitm_servo_dat),
      .wb_we_i(wb_mitm_servo_we),
      .wb_cyc_i(wb_mitm_servo_cyc),
      .wb_stb_i(wb_mitm_servo_stb),
      .wb_sel_i(wb_mitm_servo_sel),
      .wb_cti_i(wb_mitm_servo_cti),
      .wb_bte_i(wb_mitm_servo_bte),
      .wb_ack_o(wb_mitm_servo_ack),
      .wb_err_o(wb_mitm_servo_err),
      .wb_rty_o(wb_mitm_servo_rty),
      .wb_dat_o(wb_mitm_servo_rdt),
      .debug_state(servo_state),
      .debug_tx_active(),
      .debug_rx_active(),
      .debug_tx_empty(),
      .debug_rx_empty(),
      .debug_tx_full(),
      .debug_rx_full(),
      .debug_data_tx(servo_data_tx),
      .debug_pop_tx(),
      .debug_data_rx(servo_data_rx),
      .debug_byte_rx(servo_byte_rx),
      .debug_estado_rx(servo_estado_rx),
      .debug_estado_tx(servo_estado_tx)
  );
  uart_half_duplex_wb #(
      .F_MHZ(F_MHZ),
      .BAUDIOS(BAUDIOS),
      .FIFO_DEPTH(UART_FIFO_DEPTH),
      .WB_ADDR_DIR(UART_CAPTURER_WB_ADDR_SIZE),
      .WB_DATA_WIDTH(WB_DATA)
  ) uart_capturer (
      .wb_clk  (clk),
      .wb_rst  (wb_rst || rst),
      //.rx(rx),
      //.tx(tx),
      .bus_data(bus_data_capturer),

      .wb_adr_i(wb_mitm_capturer_adr),
      .wb_dat_i(wb_mitm_capturer_dat),
      .wb_we_i(wb_mitm_capturer_we),
      .wb_cyc_i(wb_mitm_capturer_cyc),
      .wb_stb_i(wb_mitm_capturer_stb),
      .wb_sel_i(wb_mitm_capturer_sel),
      .wb_cti_i(wb_mitm_capturer_cti),
      .wb_bte_i(wb_mitm_capturer_bte),
      .wb_ack_o(wb_mitm_capturer_ack),
      .wb_err_o(wb_mitm_capturer_err),
      .wb_rty_o(wb_mitm_capturer_rty),
      .wb_dat_o(wb_mitm_capturer_rdt),
      .debug_state(capturer_state),
      .debug_tx_active(),
      .debug_rx_active(),
      .debug_tx_empty(),
      .debug_rx_empty(),
      .debug_tx_full(),
      .debug_rx_full(),
      .debug_data_tx(capturer_data_tx),
      .debug_data_rx(capturer_data_rx),
      .debug_byte_rx(capturer_byte_rx),
      .debug_pop_tx(),
      .debug_estado_rx(capturer_estado_rx),
      .debug_estado_tx(capturer_estado_tx)
  );

  ax12a #(
      .FILE_MEM(FILE_MEM),
      .MAX_NUM_PARAMETERS_ALLOWED(MAX_NUM_PARAMETERS_ALLOWED),
      .WB_DATA_WIDTH(WB_DATA),
      .WB_ADDR_DIR(IMPOSTOR_WB_ADDR_SIZE)
  ) impostor (
      .wb_clk(clk),
      .wb_rst(wb_rst || rst),

      .wb_adr_i(wb_mitm_impostor_adr),
      .wb_dat_i(wb_mitm_impostor_dat),
      .wb_we_i(wb_mitm_impostor_we),
      .wb_cyc_i(wb_mitm_impostor_cyc),
      .wb_stb_i(wb_mitm_impostor_stb),
      .wb_sel_i(wb_mitm_impostor_sel),
      .wb_cti_i(wb_mitm_impostor_cti),
      .wb_bte_i(wb_mitm_impostor_bte),
      .wb_ack_o(wb_mitm_impostor_ack),
      .wb_err_o(wb_mitm_impostor_err),
      .wb_rty_o(wb_mitm_impostor_rty),
      .wb_dat_o(wb_mitm_impostor_rdt),
      .debug_state(impostor_state),
      .debug_checksum(impostor_checksum),
      .debug_bank_reg_inst(impostor_bank_inst)
  );


  shaper #(
      .FILE_MEM(SHAPER_FILE_MEM),
      .WB_DATA_WIDTH(WB_DATA),
      .WB_ADDR_DIR(SHAPER_WB_ADDR),
      .MAX_NUM_PARAMETERS_ALLOWED(MAX_NUM_PARAMETERS_ALLOWED)
  ) shaper_inst (
      .wb_clk(clk),
      .wb_rst(wb_rst || rst),

      .wb_adr_i(wb_mitm_shaper_adr),
      .wb_dat_i(wb_mitm_shaper_dat),
      .wb_we_i(wb_mitm_shaper_we),
      .wb_cyc_i(wb_mitm_shaper_cyc),
      .wb_stb_i(wb_mitm_shaper_stb),
      .wb_sel_i(wb_mitm_shaper_sel),
      .wb_cti_i(wb_mitm_shaper_cti),
      .wb_bte_i(wb_mitm_shaper_bte),
      .wb_ack_o(wb_mitm_shaper_ack),
      .wb_err_o(wb_mitm_shaper_err),
      .wb_rty_o(wb_mitm_shaper_rty),
      .wb_dat_o(wb_mitm_shaper_rdt),
      .debug_state(shaper_state)
  );
endmodule
