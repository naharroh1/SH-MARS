/**
 * File              : attack_mode_0.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 05.05.2025
 * Last Modified Date: 05.05.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module attack_mode_0 #(
    parameter WB_DATA = 32,
    parameter UART_SERVO_ADDR = 32'h4000,
    parameter UART_CAPTURER_ADDR = 32'h8000
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

    output [4:0] debug_state
);

  assign debug_state = current_state;

  localparam UART_SERVO_SEND_DATA_ADDR = UART_SERVO_ADDR + 0;
  localparam UART_SERVO_RCV_DATA_ADDR = UART_SERVO_ADDR + 1;
  localparam UART_SERVO_CTRL_UART = UART_SERVO_ADDR + 2;

  localparam UART_CAPTURER_SEND_DATA_ADDR = UART_CAPTURER_ADDR + 0;
  localparam UART_CAPTURER_RCV_DATA_ADDR = UART_CAPTURER_ADDR + 1;
  localparam UART_CAPTURER_CTRL_UART = UART_CAPTURER_ADDR + 2;

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


  logic [4:0] current_state, next_state;
  localparam RST_STATE = 0;
  localparam IDLE = 1;
  localparam CHECK_UART_CAPTURER = 2;
  localparam CHECK_UART_SERVO = 3;
  localparam DATA_CAPTURER_RECEIVED = 4;
  localparam DATA_SERVO_RECEIVED = 5;
  localparam GET_DATA_UART_CAPTURER_0 = 6;
  localparam GET_DATA_UART_CAPTURER_1 = 7;
  localparam GET_DATA_UART_CAPTURER_2 = 8;
  localparam RECV_DATA_UART_CAPTURER_0 = 9;
  localparam RECV_DATA_UART_CAPTURER_1 = 10;
  localparam SEND_DATA_UART_CAPTURER_0 = 11;
  localparam SEND_DATA_UART_CAPTURER_1 = 12;
  localparam GET_DATA_UART_SERVO_0 = 13;
  localparam GET_DATA_UART_SERVO_1 = 14;
  localparam GET_DATA_UART_SERVO_2 = 15;
  localparam RECV_DATA_UART_SERVO_0 = 16;
  localparam RECV_DATA_UART_SERVO_1 = 17;
  localparam SEND_DATA_UART_SERVO_0 = 18;
  localparam SEND_DATA_UART_SERVO_1 = 19;
  localparam WAIT_ACK = 20;
  localparam WAIT_NEG_ACK_0 = 21;
  localparam WAIT_NEG_ACK_1 = 22;



  //IDLE, wait until data is captured in UART_CAPTURER
  //segun el modo de funcionamiento
  //0: hacer de intermediario sin modificar datos
  //1: usar el modulo imposter para generar una respuesta
  //2: modificar la instruccion y enviarla al servo, paras la respuesta sin
  //modificar.



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
        next_state = CHECK_UART_CAPTURER;
      end
      CHECK_UART_CAPTURER: begin
        next_state = GET_DATA_UART_CAPTURER_0;
      end
      CHECK_UART_SERVO: begin
        next_state = GET_DATA_UART_SERVO_0;
      end

      DATA_CAPTURER_RECEIVED: begin
        next_state = SEND_DATA_UART_SERVO_0;
        r_jmp_state_w = 1;
        r_jmp_state_i = IDLE;
      end

      DATA_SERVO_RECEIVED: begin
        next_state = SEND_DATA_UART_CAPTURER_0;
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
          next_state = IDLE;
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

