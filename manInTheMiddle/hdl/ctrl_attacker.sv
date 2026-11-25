/**
 * File              : ctrl_attacker.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 24.04.2025
 * Last Modified Date: 24.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module ctrl_attacker #(
    parameter WB_DATA = 32,
    parameter UART_SERVO_ADDR = 32'h4000,
    parameter UART_CAPTURER_ADDR = 32'h8000,
    parameter IMPOSTOR_ADDR = 32'hA00,
    parameter SHAPER_ADDR = 32'h200,
    parameter NUM_MODES = 4
) (
    input wb_clk,
    input rst,

    output logic                    wb_rst_o,
    input                           wb_ack_i,
    input                           wb_err_i,
    input        [   WB_DATA - 1:0] wb_dat_i,
    input                           wb_rty_i,
    output logic [   WB_DATA - 1:0] wb_dat_o,
    output logic                    wb_cyc_o,
    output logic                    wb_stb_o,
    output logic [(WB_DATA>>3)-1:0] wb_sel_o,
    output logic                    wb_we_o,
    output logic [             2:0] wb_cti_o,
    output logic [             1:0] wb_bte_o,
    output       [     WB_DATA-1:0] wb_adr_o,

    input [1:0] attack_mode,
    input trigger_mod_mem,
    input [5:0] mem_shaper_addr,
    input [7:0] mem_shaper_data,
    output [5:0] debug_state
);

  logic [5:0] debug_state_modes[NUM_MODES-1:0];

  logic [0:0] rst_modes[NUM_MODES-1:0];
  logic [0:0] wb_rst_o_modes[NUM_MODES-1:0];
  logic [0:0] wb_ack_i_modes[NUM_MODES-1:0];
  logic [0:0] wb_err_i_modes[NUM_MODES-1:0];
  logic [WB_DATA-1:0] wb_dat_i_modes[NUM_MODES-1:0];
  logic [0:0] wb_rty_i_modes[NUM_MODES-1:0];
  logic [WB_DATA-1:0] wb_dat_o_modes[NUM_MODES-1:0];
  logic [0:0] wb_cyc_o_modes[NUM_MODES-1:0];
  logic [0:0] wb_stb_o_modes[NUM_MODES-1:0];
  logic [(WB_DATA>>3)-1:0] wb_sel_o_modes[NUM_MODES-1:0];
  logic [0:0] wb_we_o_modes[NUM_MODES-1:0];
  logic [2:0] wb_cti_o_modes[NUM_MODES-1:0];
  logic [1:0] wb_bte_o_modes[NUM_MODES-1:0];
  logic [WB_DATA-1:0] wb_adr_o_modes[NUM_MODES-1:0];

  assign wb_dat_o = wb_dat_o_modes[attack_mode];
  assign wb_cyc_o = wb_cyc_o_modes[attack_mode];
  assign wb_stb_o = wb_stb_o_modes[attack_mode];
  assign wb_sel_o = wb_sel_o_modes[attack_mode];
  assign wb_we_o = wb_we_o_modes[attack_mode];
  assign wb_cti_o = wb_cti_o_modes[attack_mode];
  assign wb_bte_o = wb_bte_o_modes[attack_mode];
  assign wb_rst_o = wb_rst_o_modes[attack_mode];
  assign wb_adr_o = wb_adr_o_modes[attack_mode];
  assign debug_state = debug_state_modes[attack_mode];

  genvar i;

  generate
    for (i = 0; i < NUM_MODES; i++) begin
      assign rst_modes[i] = (attack_mode == i) ? 0 : 1;
      assign wb_ack_i_modes[i] = wb_ack_i;
      assign wb_err_i_modes[i] = wb_err_i;
      assign wb_dat_i_modes[i] = wb_dat_i;
      assign wb_rty_i_modes[i] = wb_rty_i;
    end
  endgenerate

  attack_mode_0 #(
      .WB_DATA(WB_DATA),
      .UART_SERVO_ADDR(UART_SERVO_ADDR),
      .UART_CAPTURER_ADDR(UART_CAPTURER_ADDR)
  ) mode0 (
      .wb_clk(wb_clk),
      .rst(rst | rst_modes[0]),
      .wb_rst_o(wb_rst_o_modes[0]),
      .wb_ack_i(wb_ack_i_modes[0]),
      .wb_err_i(wb_err_i_modes[0]),
      .wb_dat_i(wb_dat_i_modes[0]),
      .wb_rty_i(wb_rty_i_modes[0]),
      .wb_dat_o(wb_dat_o_modes[0]),
      .wb_cyc_o(wb_cyc_o_modes[0]),
      .wb_stb_o(wb_stb_o_modes[0]),
      .wb_sel_o(wb_sel_o_modes[0]),
      .wb_we_o(wb_we_o_modes[0]),
      .wb_cti_o(wb_cti_o_modes[0]),
      .wb_bte_o(wb_bte_o_modes[0]),
      .wb_adr_o(wb_adr_o_modes[0]),
      .debug_state(debug_state_modes[0])
  );

  attack_mode_1 #(
      .WB_DATA(WB_DATA),
      .IMPOSTOR_ADDR(IMPOSTOR_ADDR),
      .UART_CAPTURER_ADDR(UART_CAPTURER_ADDR)
  ) mode1 (
      .wb_clk(wb_clk),
      .rst(rst | rst_modes[1]),
      .wb_rst_o(wb_rst_o_modes[1]),
      .wb_ack_i(wb_ack_i_modes[1]),
      .wb_err_i(wb_err_i_modes[1]),
      .wb_dat_i(wb_dat_i_modes[1]),
      .wb_rty_i(wb_rty_i_modes[1]),
      .wb_dat_o(wb_dat_o_modes[1]),
      .wb_cyc_o(wb_cyc_o_modes[1]),
      .wb_stb_o(wb_stb_o_modes[1]),
      .wb_sel_o(wb_sel_o_modes[1]),
      .wb_we_o(wb_we_o_modes[1]),
      .wb_cti_o(wb_cti_o_modes[1]),
      .wb_bte_o(wb_bte_o_modes[1]),
      .wb_adr_o(wb_adr_o_modes[1]),
      .debug_state(debug_state_modes[1])
  );

  attack_mode_2 #(
      .WB_DATA(WB_DATA),
      .IMPOSTOR_ADDR(IMPOSTOR_ADDR),
      .UART_CAPTURER_ADDR(UART_CAPTURER_ADDR),
      .UART_SERVO_ADDR(UART_SERVO_ADDR),
      .SHAPER_ADDR(SHAPER_ADDR)
  ) mode2 (
      .wb_clk(wb_clk),
      .rst(rst | rst_modes[2]),
      .wb_rst_o(wb_rst_o_modes[2]),
      .wb_ack_i(wb_ack_i_modes[2]),
      .wb_err_i(wb_err_i_modes[2]),
      .wb_dat_i(wb_dat_i_modes[2]),
      .wb_rty_i(wb_rty_i_modes[2]),
      .wb_dat_o(wb_dat_o_modes[2]),
      .wb_cyc_o(wb_cyc_o_modes[2]),
      .wb_stb_o(wb_stb_o_modes[2]),
      .wb_sel_o(wb_sel_o_modes[2]),
      .wb_we_o(wb_we_o_modes[2]),
      .wb_cti_o(wb_cti_o_modes[2]),
      .wb_bte_o(wb_bte_o_modes[2]),
      .wb_adr_o(wb_adr_o_modes[2]),
      .mem_shaper_addr(mem_shaper_addr),
      .mem_shaper_data(mem_shaper_data),
      .trigger_mod_mem(trigger_mod_mem),
      .debug_state(debug_state_modes[2])
  );

  attack_mode_3 #(
      .WB_DATA(WB_DATA),
      .UART_CAPTURER_ADDR(UART_CAPTURER_ADDR),
      .UART_SERVO_ADDR(UART_SERVO_ADDR),
      .SHAPER_ADDR(SHAPER_ADDR)
  ) mode3 (
      .wb_clk(wb_clk),
      .rst(rst | rst_modes[3]),
      .wb_rst_o(wb_rst_o_modes[3]),
      .wb_ack_i(wb_ack_i_modes[3]),
      .wb_err_i(wb_err_i_modes[3]),
      .wb_dat_i(wb_dat_i_modes[3]),
      .wb_rty_i(wb_rty_i_modes[3]),
      .wb_dat_o(wb_dat_o_modes[3]),
      .wb_cyc_o(wb_cyc_o_modes[3]),
      .wb_stb_o(wb_stb_o_modes[3]),
      .wb_sel_o(wb_sel_o_modes[3]),
      .wb_we_o(wb_we_o_modes[3]),
      .wb_cti_o(wb_cti_o_modes[3]),
      .wb_bte_o(wb_bte_o_modes[3]),
      .wb_adr_o(wb_adr_o_modes[3]),
      .mem_shaper_addr(mem_shaper_addr),
      .mem_shaper_data(mem_shaper_data),
      .trigger_mod_mem(trigger_mod_mem),
      .debug_state(debug_state_modes[3])
  );
endmodule
