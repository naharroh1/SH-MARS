/**
 * File              : attack_mode_3.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 16.05.2025
 * Last Modified Date: 16.05.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */

module attack_mode_3 #(
    parameter WB_DATA = 32,
    parameter UART_CAPTURER_ADDR = 32'h8000,
    parameter UART_SERVO_ADDR = 32'h400,
    parameter SHAPER_ADDR = 32'hA00
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

    input [7:0] mem_shaper_addr,
    input [7:0] mem_shaper_data,

    input trigger_mod_mem,

    output [5:0] debug_state
);

  assign debug_state = current_state;

  localparam UART_CAPTURER_SEND_DATA_ADDR = UART_CAPTURER_ADDR + 0;
  localparam UART_CAPTURER_RCV_DATA_ADDR = UART_CAPTURER_ADDR + 1;
  localparam UART_CAPTURER_CTRL_UART = UART_CAPTURER_ADDR + 2;

  localparam UART_SERVO_SEND_DATA_ADDR = UART_SERVO_ADDR + 0;
  localparam UART_SERVO_RCV_DATA_ADDR = UART_SERVO_ADDR + 1;
  localparam UART_SERVO_CTRL_UART = UART_SERVO_ADDR + 2;


  localparam SHAPER_SEND_DATA_TO_ADDR = SHAPER_ADDR + 0;
  localparam SHAPER_SEND_DATA_FROM_ADDR = SHAPER_ADDR + 1;
  localparam SHAPER_CTRL_ADDR = SHAPER_ADDR + 2;
  localparam SHAPER_MOD_MEM_ADDR = SHAPER_ADDR + 3;


  logic [7:0] r_jmp_state_i, jmp_state;
  logic r_jmp_state_w, r_jmp_state_rd;
  stack #(
      .FIFO_LIFO(1),
      .DEPTH(8),
      .WIDTH(8)
  ) lifo_jmp_state (
      .clk(wb_clk),
      .rst(rst),
      .data_i(r_jmp_state_i),
      .data_o(jmp_state),
      .push(r_jmp_state_w),
      .pop(r_jmp_state_rd),
      .empty(),
      .full(),
      .sp_index()
  );

  logic r_wb_dat_i_cl;
  logic r_wb_dat_i_w;
  logic [WB_DATA-1:0] r_wb_dat_i_dout;
  register #(
      .DATA_WIDTH(WB_DATA)
  ) r_wb_dat_i (
      .clk(wb_clk),
      .cl(r_wb_dat_i_cl),
      .w(r_wb_dat_i_w),
      .din(wb_dat_i),
      .dout(r_wb_dat_i_dout)
  );

  logic r_wb_adr_o_cl;
  logic r_wb_adr_o_w;
  logic [WB_DATA-1:0] r_wb_adr_o_din;
  register #(
      .DATA_WIDTH(WB_DATA)
  ) r_wb_adr_o (
      .clk(wb_clk),
      .cl(r_wb_adr_o_cl),
      .w(r_wb_adr_o_w),
      .din(r_wb_adr_o_din),
      .dout(wb_adr_o)
  );


  logic [5:0] current_state, next_state;
  localparam RST_STATE = 0;
  localparam IDLE = 1;
  localparam CHECK_UART_CAPTURER = 2;
  localparam CHECK_UART_SERVO = 3;
  localparam CHECK_SHAPER = 4;
  localparam DATA_CAPTURER_RECEIVED = 5;
  localparam DATA_SERVO_RECEIVED = 6;
  localparam DATA_SHAPER_RECEIVED = 7;
  localparam GET_DATA_UART_CAPTURER_0 = 8;
  localparam GET_DATA_UART_CAPTURER_1 = 9;
  localparam GET_DATA_UART_CAPTURER_2 = 10;
  localparam RECV_DATA_UART_CAPTURER_0 = 11;
  localparam RECV_DATA_UART_CAPTURER_1 = 12;
  localparam SEND_DATA_UART_CAPTURER_0 = 13;
  localparam SEND_DATA_UART_CAPTURER_1 = 14;
  localparam GET_DATA_SHAPER_0 = 15;
  localparam GET_DATA_SHAPER_1 = 16;
  localparam GET_DATA_SHAPER_2 = 17;
  localparam RECV_DATA_SHAPER_0 = 18;
  localparam RECV_DATA_SHAPER_1 = 19;
  localparam SEND_DATA_SHAPER_0 = 20;
  localparam SEND_DATA_SHAPER_1 = 21;
  localparam GET_DATA_UART_SERVO_0 = 22;
  localparam GET_DATA_UART_SERVO_1 = 23;
  localparam GET_DATA_UART_SERVO_2 = 24;
  localparam RECV_DATA_UART_SERVO_0 = 25;
  localparam RECV_DATA_UART_SERVO_1 = 26;
  localparam SEND_DATA_UART_SERVO_0 = 27;
  localparam SEND_DATA_UART_SERVO_1 = 28;
  localparam MOD_MEM_SHAPER_0 = 29;
  localparam MOD_MEM_SHAPER_1 = 30;
  localparam WAIT_ACK = 31;
  localparam WAIT_NEG_ACK_0 = 32;
  localparam WAIT_NEG_ACK_1 = 33;



  //IDLE, wait until data is captured in UART_CAPTURER
  //segun el modo de funcionamiento
  //0: hacer de intermediario sin modificar datos
  //1: usar el modulo imposter para generar una respuesta
  //2: modificar la instruccion y enviarla al servo, usar el imposter para
  //responder al usuario
  //3: usar shaper para modificar instruccion y reenviarla al servo, esperar
  //su respuesta y devolversela al usuario



  always_comb begin
    next_state = current_state;

    wb_dat_o = 0;
    wb_cyc_o = 0;
    wb_stb_o = 0;
    wb_sel_o = 0;
    wb_we_o = 0;
    wb_cti_o = 0;
    wb_bte_o = 0;
    wb_rst_o = 0;

    r_wb_adr_o_w = 0;
    r_wb_adr_o_cl = 0;
    r_wb_adr_o_din = 0;

    r_wb_dat_i_w = 0;
    r_wb_dat_i_cl = 0;

    r_jmp_state_rd = 0;
    r_jmp_state_i = 0;
    r_jmp_state_w = 0;

    case (current_state)
      RST_STATE: begin
        wb_rst_o = 1;
        r_wb_adr_o_cl = 1;
        r_wb_dat_i_cl = 1;
        next_state = IDLE;
      end
      IDLE: begin
        if (trigger_mod_mem) begin
          next_state = MOD_MEM_SHAPER_0;
        end else begin
          next_state = CHECK_UART_CAPTURER;
        end
      end
      CHECK_UART_CAPTURER: begin
        next_state = GET_DATA_UART_CAPTURER_0;
      end
      CHECK_UART_SERVO: begin
        next_state = GET_DATA_UART_SERVO_0;
      end
      CHECK_SHAPER: begin
        next_state = GET_DATA_SHAPER_0;
      end
      MOD_MEM_SHAPER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SHAPER_MOD_MEM_ADDR;
        next_state = MOD_MEM_SHAPER_1;
      end
      MOD_MEM_SHAPER_1: begin
        wb_dat_o = {mem_shaper_data, mem_shaper_addr};
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};
        if (wb_ack_i == 1) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = IDLE;
          next_state = WAIT_NEG_ACK_0;
        end
      end

      DATA_CAPTURER_RECEIVED: begin
        next_state = SEND_DATA_SHAPER_0;
        r_jmp_state_w = 1;
        r_jmp_state_i = IDLE;
      end

      DATA_SERVO_RECEIVED: begin
        next_state = SEND_DATA_UART_CAPTURER_0;
        r_jmp_state_i = IDLE;
        r_jmp_state_w = 1;
      end

      DATA_SHAPER_RECEIVED: begin
        next_state = SEND_DATA_UART_SERVO_0;
        r_jmp_state_i = IDLE;
        r_jmp_state_w = 1;
      end


      GET_DATA_UART_CAPTURER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CAPTURER_CTRL_UART;
        next_state = GET_DATA_UART_CAPTURER_1;
      end
      GET_DATA_UART_CAPTURER_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_i = GET_DATA_UART_CAPTURER_2;
          r_jmp_state_w = 1;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      GET_DATA_UART_CAPTURER_2: begin
        if (r_wb_dat_i_dout[3:0] == 0) begin
          next_state = CHECK_UART_SERVO;
        end else begin
          next_state = RECV_DATA_UART_CAPTURER_0;
        end
      end
      RECV_DATA_UART_CAPTURER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CAPTURER_RCV_DATA_ADDR;
        next_state = RECV_DATA_UART_CAPTURER_1;
      end
      RECV_DATA_UART_CAPTURER_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = DATA_CAPTURER_RECEIVED;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end

      SEND_DATA_UART_CAPTURER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CAPTURER_SEND_DATA_ADDR;
        next_state = SEND_DATA_UART_CAPTURER_1;
      end
      SEND_DATA_UART_CAPTURER_1: begin
        wb_dat_o = r_wb_dat_i_dout;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};
        if (wb_ack_i == 1) begin
          next_state = WAIT_NEG_ACK_0;
        end
      end
      GET_DATA_UART_SERVO_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SERVO_CTRL_UART;
        next_state = GET_DATA_UART_SERVO_1;
      end
      GET_DATA_UART_SERVO_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_i = GET_DATA_UART_SERVO_2;
          r_jmp_state_w = 1;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      GET_DATA_UART_SERVO_2: begin
        if (r_wb_dat_i_dout[3:0] == 0) begin
          next_state = CHECK_SHAPER;
        end else begin
          next_state = RECV_DATA_UART_SERVO_0;
        end
      end
      RECV_DATA_UART_SERVO_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SERVO_RCV_DATA_ADDR;
        next_state = RECV_DATA_UART_SERVO_1;
      end
      RECV_DATA_UART_SERVO_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = DATA_SERVO_RECEIVED;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      SEND_DATA_UART_SERVO_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SERVO_SEND_DATA_ADDR;
        next_state = SEND_DATA_UART_SERVO_1;
      end
      SEND_DATA_UART_SERVO_1: begin
        wb_dat_o = r_wb_dat_i_dout;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};
        if (wb_ack_i == 1) begin
          next_state = WAIT_NEG_ACK_0;
        end
      end
      GET_DATA_SHAPER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SHAPER_CTRL_ADDR;
        next_state = GET_DATA_SHAPER_1;
      end
      GET_DATA_SHAPER_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_i = GET_DATA_SHAPER_2;
          r_jmp_state_w = 1;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      GET_DATA_SHAPER_2: begin
        if ((r_wb_dat_i_dout & 1'h1) != 1) begin
          next_state = IDLE;
        end else begin
          next_state = RECV_DATA_SHAPER_0;
        end
      end
      RECV_DATA_SHAPER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SHAPER_SEND_DATA_FROM_ADDR;
        next_state = RECV_DATA_SHAPER_1;
      end
      RECV_DATA_SHAPER_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 0;
        wb_sel_o = 0;
        if (wb_ack_i == 1) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = DATA_SHAPER_RECEIVED;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      SEND_DATA_SHAPER_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SHAPER_SEND_DATA_TO_ADDR;
        next_state = SEND_DATA_SHAPER_1;
      end
      SEND_DATA_SHAPER_1: begin
        wb_dat_o = r_wb_dat_i_dout;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};
        if (wb_ack_i == 1) begin
          next_state = WAIT_NEG_ACK_0;
        end
      end
      WAIT_ACK: begin
        if (wb_ack_i == 1) begin
          next_state = WAIT_NEG_ACK_0;
        end
      end
      WAIT_NEG_ACK_0: begin
        r_jmp_state_rd = 1;
        next_state = WAIT_NEG_ACK_1;
      end
      WAIT_NEG_ACK_1: begin
        if (wb_ack_i == 0) begin
          next_state = jmp_state;
        end
      end
    endcase

  end


  always_ff @(posedge wb_clk) begin
    if (rst) begin
      current_state <= RST_STATE;
    end else begin
      current_state <= next_state;
    end
  end

endmodule


