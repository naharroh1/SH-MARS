/**
 * File              : ctrl_dynamixel.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 07.04.2025
 * Last Modified Date: 07.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module ctrl_dynamixel #(
    parameter WB_DATA = 32,
    parameter UART_WB_ADDR = 32'h40000000,
    parameter SDSPI_WB_ADDR = 32'h60000000
) (
    input                           wb_clk,
    input                           rst,
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


    input start,
    output logic err,
    input [4:0] sclk_speed,
    input [WB_DATA-1 : 0] base_addr_for_inst,
    output [5:0] debug_state,
    output [WB_DATA-1 : 0] debug_r_wb_dat_i_dout,
    output [31:0] debug_counter_inst
);

  assign debug_r_wb_dat_i_dout = r_wb_dat_i_dout;
  assign debug_counter_inst = counter_len_inst_dout;
  //ctrl_dynamixel
  //formato de instruccion en SD sincr1, sincr2, len, id, instruction,
  //parameters ..., checksum, ptr_next_inst
  //o bien poner todas de forma consecutiva
  //o bien almacenar la respuesta tras la instruccion.
  //1. Pide instruccion, byte a byte
  //2. Envia al motor los bytes de la instruccion
  //3. Espera la respuesta del motor
  //4. 

  localparam UART_SEND_DATA_ADDR = UART_WB_ADDR + 0;
  localparam UART_RCV_DATA_ADDR = UART_WB_ADDR + 1;
  localparam UART_CTRL_UART = UART_WB_ADDR + 2;

  localparam SDSPI_SET_ADDRESS_ADDR = SDSPI_WB_ADDR + 0;
  localparam SDSPI_WRITE_BYTE_ADDR = SDSPI_WB_ADDR + 1;
  localparam SDSPI_READ_BYTE_ADDR = SDSPI_WB_ADDR + 2;
  localparam SDSPI_SET_SPEED_ADDR = SDSPI_WB_ADDR + 3;
  localparam SDSPI_STOP_ADDR = SDSPI_WB_ADDR + 4;

  logic [7:0] r_jmp_state_i, jmp_state;
  logic r_jmp_state_w, r_jmp_state_rd;
  stack_fifo #(
      .DEPTH(8),
      .WIDTH(8)
  ) fifo_jmp_state (
      .clk(wb_clk),
      .rst(rst),
      .data_i(r_jmp_state_i),
      .data_o(jmp_state),
      .push(r_jmp_state_w),
      .pop(r_jmp_state_rd),
      .empty(),
      .full()
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

  logic r_checksum_cl;
  logic r_checksum_w;
  logic [7:0] r_checksum_dat_i, r_checksum_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_checksum (
      .clk(wb_clk),
      .cl(r_checksum_cl),
      .w(r_checksum_w),
      .din(r_checksum_dat_i),
      .dout(r_checksum_dat_o)
  );

  logic counter_len_inst_rst, counter_len_inst_down;
  logic [7:0] counter_len_inst_dout;
  counter_limit #(
      .DATA_WIDTH(8)
  ) counter_inst (
      .clk (wb_clk),
      .rst (counter_len_inst_rst),
      .up  (0),
      .down(counter_len_inst_down),
      .din (r_wb_dat_i_dout),
      .dout(counter_len_inst_dout)
  );

  logic timeout_rst;
  logic [31:0] timeout_dout;

  counter_limit #(
      .DATA_WIDTH(32)
  ) timeout_counter (
      .clk (wb_clk),
      .rst (timeout_rst),
      .up  (0),
      .down(1),
      .din (32'h3C000000),
      .dout(timeout_dout)
  );

  localparam CTRL_NOT_READ_AFTER_SEND = 0;
  logic r_ctrl_cl;
  logic r_ctrl_w;
  logic [7:0] r_ctrl_dat_i, r_ctrl_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_ctrl (
      .clk(wb_clk),
      .cl(r_ctrl_cl),
      .w(r_ctrl_w),
      .din(r_ctrl_dat_i),
      .dout(r_ctrl_dat_o)
  );

  logic [5:0] current_state, next_state;
  assign debug_state = current_state;
  localparam RST_STATE = 0;
  localparam IDLE = 1;
  localparam SETUP_SDSPI_0 = 2;
  localparam SETUP_SDSPI_1 = 3;
  localparam SET_ADDR_FOR_INST_0 = 4;
  localparam SET_ADDR_FOR_INST_1 = 5;
  localparam SEND_INST_0 = 6;
  localparam CHECK_SYNC_0 = 7;
  localparam CHECK_SYNC_1 = 8;
  localparam INST_ID = 9;
  localparam INST_LEN = 10;
  localparam LOOP_INST = 11;
  localparam CHEKSUM_0 = 12;
  localparam CHEKSUM_1 = 13;
  localparam RCV_RESPONSE = 14;
  localparam RSP_SYNC_0 = 15;
  localparam RSP_SYNC_1 = 16;
  localparam RSP_ID = 17;
  localparam RSP_LEN = 18;
  localparam RSP_ERR = 19;
  localparam LOOP_RSP = 20;
  localparam END_STATE = 21;
  localparam GET_DATA_UART_0 = 22;
  localparam GET_DATA_UART_1 = 23;
  localparam GET_DATA_UART_2 = 24;
  localparam RECV_DATA_UART_0 = 25;
  localparam RECV_DATA_UART_1 = 26;
  localparam SEND_BYTE_0 = 27;
  localparam SEND_BYTE_1 = 28;
  localparam READ_BYTE_0 = 29;
  localparam READ_BYTE_1 = 30;
  localparam WAIT_ACK = 31;
  localparam WAIT_NEG_ACK_0 = 32;
  localparam WAIT_NEG_ACK_1 = 33;


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

    r_checksum_w = 0;
    r_checksum_cl = 0;
    r_checksum_dat_i = 0;

    r_ctrl_w = 0;
    r_ctrl_cl = 0;
    r_ctrl_dat_i = 0;

    counter_len_inst_rst = 0;
    counter_len_inst_down = 0;

    err = 0;

    timeout_rst = 1;


    case (current_state)
      RST_STATE: begin
        wb_rst_o = 1;
        r_wb_adr_o_cl = 1;
        r_wb_dat_i_cl = 1;
        r_ctrl_cl = 1;
        next_state = IDLE;
      end
      IDLE: begin
        r_wb_adr_o_cl = 1;
        if (start == 1) begin
          next_state = SETUP_SDSPI_0;
        end
      end
      SETUP_SDSPI_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SDSPI_SET_SPEED_ADDR;
        next_state = SETUP_SDSPI_1;
      end
      SETUP_SDSPI_1: begin
        wb_dat_o = sclk_speed;  //25 MHz at 100 MHz
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};

        r_jmp_state_w = 1;
        r_jmp_state_i = SET_ADDR_FOR_INST_0;

        next_state = WAIT_ACK;

      end
      SET_ADDR_FOR_INST_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SDSPI_SET_ADDRESS_ADDR;
        next_state = SET_ADDR_FOR_INST_1;
      end
      SET_ADDR_FOR_INST_1: begin
        wb_dat_o = base_addr_for_inst;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};

        r_jmp_state_w = 1;
        r_jmp_state_i = SEND_INST_0;

        next_state = WAIT_ACK;
      end
      SEND_INST_0: begin

        r_jmp_state_w = 1;
        r_jmp_state_i = CHECK_SYNC_0;

        next_state = READ_BYTE_0;

      end
      CHECK_SYNC_0: begin
        if (r_wb_dat_i_dout == 8'hFF) begin
          r_jmp_state_i = CHECK_SYNC_1;
          r_jmp_state_w = 1;
          next_state = SEND_BYTE_0;
        end else begin
          err = 1;
          next_state = END_STATE;
        end
      end
      CHECK_SYNC_1: begin
        if (r_wb_dat_i_dout == 8'hFF) begin
          r_jmp_state_i = INST_ID;
          r_jmp_state_w = 1;
          next_state = SEND_BYTE_0;
        end else begin
          err = 1;
          next_state = END_STATE;
        end
      end
      INST_ID: begin
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_jmp_state_w = 1;
        r_jmp_state_i = INST_LEN;
        next_state = SEND_BYTE_0;
      end
      INST_LEN: begin
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_jmp_state_i = LOOP_INST;
        r_jmp_state_w = 1;
        counter_len_inst_rst = 1;
        next_state = SEND_BYTE_0;
      end
      LOOP_INST: begin
        /*	
        if (counter_len_inst_dout == 1) begin
          next_state = CHEKSUM_0;
        end else begin
          r_checksum_w = 1;
          r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
          counter_len_inst_down = 1;
          r_jmp_state_i = LOOP_INST;
          r_jmp_state_w = 1;
          next_state = SEND_BYTE_0;
        end
	*/
        if (counter_len_inst_dout == 0) begin
          next_state = RCV_RESPONSE;
          r_ctrl_cl  = 1;
        end else begin
          r_checksum_w = 1;
          r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
          counter_len_inst_down = 1;
          r_jmp_state_i = LOOP_INST;
          r_jmp_state_w = 1;
          next_state = SEND_BYTE_0;
          if (counter_len_inst_dout == 1) begin
            r_ctrl_w = 1;
            r_ctrl_dat_i = r_ctrl_dat_o | (1 << CTRL_NOT_READ_AFTER_SEND);
          end
        end

      end
      CHEKSUM_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SEND_DATA_ADDR;
        next_state = CHEKSUM_1;
      end
      CHEKSUM_1: begin
        wb_dat_o = ~(r_checksum_dat_o);
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};

        if (wb_ack_i == 1) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = RCV_RESPONSE;
          next_state = WAIT_NEG_ACK_0;
        end
      end
      RCV_RESPONSE: begin
        r_checksum_cl = 1;
        r_jmp_state_w = 1;
        r_jmp_state_i = RSP_SYNC_0;
        next_state = GET_DATA_UART_0;
      end
      RSP_SYNC_0: begin
        if (r_wb_dat_i_dout == 8'hFF) begin
          r_jmp_state_i = RSP_SYNC_1;
          r_jmp_state_w = 1;
          next_state = GET_DATA_UART_0;
        end else begin
          err = 1;
          next_state = END_STATE;
        end

      end
      RSP_SYNC_1: begin
        if (r_wb_dat_i_dout == 8'hFF) begin
          r_jmp_state_w = 1;
          r_jmp_state_i = RSP_ID;
          next_state = GET_DATA_UART_0;

        end else begin
          err = 1;
          next_state = END_STATE;
        end

      end
      RSP_ID: begin
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_jmp_state_i = RSP_LEN;
        r_jmp_state_w = 1;
        next_state = GET_DATA_UART_0;

      end
      RSP_LEN: begin
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_jmp_state_i = RSP_ERR;
        r_jmp_state_w = 1;
        counter_len_inst_rst = 1;
        next_state = GET_DATA_UART_0;

      end
      RSP_ERR: begin
        counter_len_inst_down = 1;
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_jmp_state_i = LOOP_RSP;
        r_jmp_state_w = 1;
        if (r_wb_dat_i_dout == 0) begin
          next_state = GET_DATA_UART_0;
        end else begin
          err = 1;
          next_state = GET_DATA_UART_0;  //END_STATE;
        end
      end
      LOOP_RSP: begin
        if (counter_len_inst_dout == 1) begin
          next_state = SEND_INST_0;
          if (~(r_checksum_dat_o) != r_wb_dat_i_dout) begin
            next_state = SEND_INST_0;  //END_STATE;
            err = 1;
          end
        end else begin
          r_checksum_w = 1;
          r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
          counter_len_inst_down = 1;
          r_jmp_state_i = LOOP_RSP;
          r_jmp_state_w = 1;
          next_state = GET_DATA_UART_0;

        end

      end


      GET_DATA_UART_0: begin
        timeout_rst = 0;
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CTRL_UART;  //ask for how many bytes are in rx fifo
        next_state = GET_DATA_UART_1;
        if (timeout_dout == 0) begin
          next_state = SEND_INST_0;
        end
      end
      GET_DATA_UART_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 0;
        wb_sel_o = 0;
        timeout_rst = 0;

        if (wb_ack_i == 1) begin
          r_jmp_state_i = GET_DATA_UART_2;
          r_jmp_state_w = 1;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end

      end
      GET_DATA_UART_2: begin
        timeout_rst = 0;
        if (r_wb_dat_i_dout == 0) begin
          next_state = GET_DATA_UART_0;
        end else begin
          next_state = RECV_DATA_UART_0;
        end

      end
      RECV_DATA_UART_0: begin
        timeout_rst = 0;
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_RCV_DATA_ADDR;
        next_state = RECV_DATA_UART_1;
      end
      RECV_DATA_UART_1: begin
        timeout_rst = 0;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 0;
        wb_sel_o = 0;
        if (timeout_dout == 0) begin
          next_state = SEND_INST_0;
        end

        if (wb_ack_i == 1) begin
          r_wb_dat_i_w = 1;
          next_state   = WAIT_NEG_ACK_0;
        end

      end
      SEND_BYTE_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SEND_DATA_ADDR;
        next_state = SEND_BYTE_1;
      end
      SEND_BYTE_1: begin
        wb_dat_o = r_wb_dat_i_dout;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};

        if (wb_ack_i == 1) begin
          r_jmp_state_w = (r_ctrl_dat_o & (1 << CTRL_NOT_READ_AFTER_SEND)) ? 0 : 1;
          r_jmp_state_i = READ_BYTE_0;
          next_state = WAIT_NEG_ACK_0;
        end


      end
      READ_BYTE_0: begin
        timeout_rst = 0;
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = SDSPI_READ_BYTE_ADDR;
        next_state = READ_BYTE_1;
      end
      READ_BYTE_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 0;
        wb_sel_o = 0;
        timeout_rst = 0;

        if (wb_ack_i == 1) begin
          r_wb_dat_i_w = 1;
          next_state   = WAIT_NEG_ACK_0;
        end
        if (timeout_dout == 0) begin
          timeout_rst = 1;
          next_state  = SEND_INST_0;
        end
      end
      WAIT_ACK: begin
        timeout_rst = 0;
        if (wb_ack_i == 1) begin
          next_state = WAIT_NEG_ACK_0;
        end
      end
      WAIT_NEG_ACK_0: begin
        timeout_rst = 0;
        r_jmp_state_rd = 1;
        next_state = WAIT_NEG_ACK_1;
      end
      WAIT_NEG_ACK_1: begin
        timeout_rst = 0;
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
