/**
 * File              : ctrl_dynamixel.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 07.04.2025
 * Last Modified Date: 07.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module ctrl_dynamixel #(
    parameter WB_DATA = 32,
    parameter MAX_NUM_PARAMETERS_ALLOWED = 8,
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
  assign debug_counter_inst = counter_recv_bytes_dout;
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
  logic [WB_DATA-1:0] r_wb_dat_i_dout, r_wb_dat_i_din;
  register #(
      .DATA_WIDTH(WB_DATA)
  ) r_wb_dat_i (
      .clk(wb_clk),
      .cl(r_wb_dat_i_cl),
      .w(r_wb_dat_i_w),
      .din(r_wb_dat_i_din),
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

  logic r_id_cl;
  logic r_id_w;
  logic [7:0] r_id_dat_i, r_id_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_id (
      .clk(wb_clk),
      .cl(r_id_cl),
      .w(r_id_w),
      .din(r_id_dat_i),
      .dout(r_id_dat_o)
  );

  logic r_len_cl;
  logic r_len_w;
  logic [7:0] r_len_dat_i, r_len_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_len (
      .clk(wb_clk),
      .cl(r_len_cl),
      .w(r_len_w),
      .din(r_len_dat_i),
      .dout(r_len_dat_o)
  );

  logic r_inst_cl;
  logic r_inst_w;
  logic [7:0] r_inst_dat_i, r_inst_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_inst (
      .clk(wb_clk),
      .cl(r_inst_cl),
      .w(r_inst_w),
      .din(r_inst_dat_i),
      .dout(r_inst_dat_o)
  );

  logic r_checksum_cl;
  logic r_checksum_w;
  logic [7:0] r_checksum_dat_i, r_checksum_dat_o, checksum_value;
  assign checksum_value = ~r_checksum_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_checksum (
      .clk(wb_clk),
      .cl(r_checksum_cl),
      .w(r_checksum_w),
      .din(r_checksum_dat_i),
      .dout(r_checksum_dat_o)
  );

  logic counter_recv_bytes_rst;
  logic counter_recv_bytes_up;
  logic [7:0] counter_recv_bytes_dout;
  counter #(
      .DATA_WIDTH(8)
  ) counter_recv_bytes (
      .clk (wb_clk),
      .rst (counter_recv_bytes_rst),
      .up  (counter_recv_bytes_up),
      .down(0),
      .din (0),
      .dout(counter_recv_bytes_dout)
  );

  logic counter_param_rst;
  logic counter_param_down;
  logic [7:0] counter_param_din;
  logic [7:0] counter_param_dout;
  counter_limit #(
      .DATA_WIDTH(8)
  ) counter_param (
      .clk (wb_clk),
      .rst (counter_param_rst),
      .up  (0),
      .down(counter_param_down),
      .din (counter_param_din),
      .dout(counter_param_dout)
  );

  genvar i;
  logic [0:0] r_param_cl[MAX_NUM_PARAMETERS_ALLOWED-1:0];
  logic [0:0] r_param_w[MAX_NUM_PARAMETERS_ALLOWED-1:0];
  logic [7:0] r_param_din[MAX_NUM_PARAMETERS_ALLOWED-1:0];
  logic [7:0] r_param_dout[MAX_NUM_PARAMETERS_ALLOWED-1:0];
  generate
    for (i = 0; i < MAX_NUM_PARAMETERS_ALLOWED; i++) begin
      register #(
          .DATA_WIDTH(8)
      ) reg_param_i (
          .clk(wb_clk),
          .cl(r_param_cl[i]),
          .w(r_param_w[i]),
          .din(r_param_din[i]),
          .dout(r_param_dout[i])
      );

    end
  endgenerate


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
      .din (32'h3c00000),
      .dout(timeout_dout)
  );

  localparam CTRL_NOT_READ_AFTER_SEND = 0;
  localparam CTRL_POSITION_L_REACHED = 1;
  localparam CTRL_POSITION_H_REACHED = 2;
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

  logic r_resp_err_cl;
  logic r_resp_err_w;
  logic [7:0] r_resp_err_dat_i, r_resp_err_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_resp_err (
      .clk(wb_clk),
      .cl(r_resp_err_cl),
      .w(r_resp_err_w),
      .din(r_resp_err_dat_i),
      .dout(r_resp_err_dat_o)
  );

  localparam MULTICAST_ADDR = 8'hFE;


  localparam ADDR_MODEL_NUMBER_L = 0;
  localparam ADDR_MODEL_NUMBER_H = 1;
  localparam ADDR_VERSION_FIRMWARE = 2;
  localparam ADDR_ID = 3;
  localparam ADDR_BAUDRATE = 4;
  localparam ADDR_RDT = 5;
  localparam ADDR_CW_ANGLE_LIMIT_L = 6;
  localparam ADDR_CW_ANGLE_LIMIT_H = 7;
  localparam ADDR_CCW_ANGLE_LIMIT_L = 8;
  localparam ADDR_CCW_ANGLE_LIMIT_H = 9;
  localparam ADDR_HIGHEST_TEMP_LIMIT = 11;
  localparam ADDR_LOWEST_VOLTAGE_LIMIT = 12;
  localparam ADDR_HIGHEST_VOLTAGE_LIMIT = 13;
  localparam ADDR_MAX_TORQUE_L = 14;
  localparam ADDR_MAX_TORQUE_H = 15;
  localparam ADDR_STATUS_RETURN_LEVEL = 16;
  localparam ADDR_ALARM_LED = 17;
  localparam ADDR_ALARM_SHUTDOWN = 18;
  localparam ADDR_DOWN_CALIBRATION_L = 20;
  localparam ADDR_DOWN_CALIBRATION_H = 21;
  localparam ADDR_UP_CALIBRATION_L = 22;
  localparam ADDR_UP_CALIBRATION_H = 23;
  localparam ADDR_TORQUE_ENABLE = 24;
  localparam ADDR_LED = 25;
  localparam ADDR_CW_COMPILANCE_MARGIN = 26;
  localparam ADDR_CCW_COMPILANCE_MARGIN = 27;
  localparam ADDR_CW_COMPILANCE_SLOPE = 28;
  localparam ADDR_CCW_COMPILANCE_SLOPE = 29;
  localparam ADDR_GOAL_POSITION_L = 30;
  localparam ADDR_GOAL_POSITION_H = 31;
  localparam ADDR_MOVING_SPEED_L = 32;
  localparam ADDR_MOVING_SPEED_H = 33;
  localparam ADDR_TORQUE_LIMIT_L = 34;
  localparam ADDR_TORQUE_LIMIT_H = 35;
  localparam ADDR_PRESENT_POSITION_L = 36;
  localparam ADDR_PRESENT_POSITION_H = 37;
  localparam ADDR_PRESENT_SPEED_L = 38;
  localparam ADDR_PRESENT_SPEED_H = 39;
  localparam ADDR_PRESENT_LOAD_L = 40;
  localparam ADDR_PRESENT_LOAD_H = 41;
  localparam ADDR_PRESENT_VOLTAGE = 42;
  localparam ADDR_PRESET_TEMP = 43;
  localparam ADDR_REGISTERED_INST = 44;
  localparam ADDR_MOVING = 46;
  localparam ADDR_LOCK = 47;
  localparam ADDR_PUNCH_L = 48;
  localparam ADDR_PUNCH_H = 49;

  localparam INST_PING = 1;
  localparam INST_READ_DATA = 2;
  localparam INST_WRITE_DATA = 3;
  localparam INST_REG_WRITE = 4;
  localparam INST_ACTION = 5;
  localparam INST_RESET = 6;
  localparam INST_SYNC_WRITE = 8'h83;

  logic [5:0] current_state, next_state;
  assign debug_state = current_state;
  localparam RST_STATE = 0;
  localparam IDLE = 1;
  localparam SETUP_SDSPI_0 = 2;
  localparam SETUP_SDSPI_1 = 3;
  localparam SET_ADDR_FOR_INST_0 = 4;
  localparam SET_ADDR_FOR_INST_1 = 5;
  localparam SEND_INST_0 = 6;
  localparam SWITCH_PROCCESS_BYTE_INST = 7;
  localparam CHECK_BYTE_INST = 8;
  localparam PARAMETERS_BYTE_INST = 9;
  localparam CHECK_CHECKSUM = 10;
  localparam CHEKSUM_1 = 11;
  localparam RCV_RESPONSE = 12;
  localparam RSP_SYNC_0 = 13;
  localparam RSP_SYNC_1 = 14;
  localparam RSP_ID = 15;
  localparam RSP_LEN = 16;
  localparam RSP_ERR = 17;
  localparam LOOP_RSP = 18;
  localparam CHECK_INST_MOVE = 19;
  localparam WAIT_SERVO_FOR_GOAL_POS_0 = 20;
  localparam WAIT_SERVO_FOR_GOAL_POS_1 = 21;
  localparam WAIT_SERVO_FOR_GOAL_POS_2 = 22;
  localparam END_STATE = 23;
  localparam GET_DATA_UART_0 = 24;
  localparam GET_DATA_UART_1 = 25;
  localparam GET_DATA_UART_2 = 26;
  localparam RECV_DATA_UART_0 = 27;
  localparam RECV_DATA_UART_1 = 28;
  localparam SEND_BYTE_0 = 29;
  localparam SEND_BYTE_1 = 30;
  localparam SEND_DIRECT_DATA_0 = 31;
  localparam SEND_DIRECT_DATA_1 = 32;
  localparam READ_BYTE_0 = 33;
  localparam READ_BYTE_1 = 34;
  localparam WAIT_ACK = 35;
  localparam WAIT_NEG_ACK_0 = 36;
  localparam WAIT_NEG_ACK_1 = 37;
  localparam WAIT_SERVO_FOR_GOAL_POS = 38;
  localparam WAIT_FOR_UART_TX_EMPTY_0 = 39;
    localparam WAIT_FOR_UART_TX_EMPTY_1 = 40;
  localparam WAIT_FOR_UART_TX_EMPTY_2 = 41;


  logic [31:0] j;

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
    r_wb_dat_i_din = wb_dat_i;

    r_jmp_state_rd = 0;
    r_jmp_state_i = 0;
    r_jmp_state_w = 0;

    r_id_cl = 0;
    r_id_w = 0;
    r_id_dat_i = 0;

    r_len_cl = 0;
    r_len_w = 0;
    r_len_dat_i = 0;

    r_inst_cl = 0;
    r_inst_w = 0;
    r_inst_dat_i = 0;

    r_checksum_w = 0;
    r_checksum_cl = 0;
    r_checksum_dat_i = 0;

    r_ctrl_w = 0;
    r_ctrl_cl = 0;
    r_ctrl_dat_i = 0;

    counter_len_inst_rst = 0;
    counter_len_inst_down = 0;

    counter_recv_bytes_up = 0;
    counter_recv_bytes_rst = 0;

    r_resp_err_cl = 0;
    r_resp_err_w = 0;
    r_resp_err_dat_i = 0;

    err = 0;

    timeout_rst = 1;

    counter_param_din = 0;
    counter_param_rst = 0;
    counter_param_down = 0;

    for (j = 0; j < MAX_NUM_PARAMETERS_ALLOWED; j++) begin
      r_param_w[j]   = 0;
      r_param_cl[j]  = 0;
      r_param_din[j] = 0;
    end

    case (current_state)
      RST_STATE: begin
        wb_rst_o = 1;
        r_wb_adr_o_cl = 1;
        r_wb_dat_i_cl = 1;
        r_ctrl_cl = 1;
        r_id_cl = 1;
        r_len_cl = 1;
        r_inst_cl = 1;
        counter_param_rst = 1;
        counter_recv_bytes_rst = 1;
        r_resp_err_cl = 1;
        for (j = 0; j < MAX_NUM_PARAMETERS_ALLOWED; j++) begin
          r_param_cl[j] = 1;
        end
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
        r_jmp_state_i = SWITCH_PROCCESS_BYTE_INST;

        next_state = READ_BYTE_0;

      end
      SWITCH_PROCCESS_BYTE_INST: begin
        if (counter_recv_bytes_dout < 5) begin
          next_state = CHECK_BYTE_INST;
        end else if (counter_param_dout > 0) begin
          next_state = PARAMETERS_BYTE_INST;
        end else begin
          next_state = CHECK_CHECKSUM;
        end
      end
      CHECK_BYTE_INST: begin
        next_state = SEND_BYTE_0;
        r_jmp_state_i = SWITCH_PROCCESS_BYTE_INST;
        r_jmp_state_w = 1;
        case (counter_recv_bytes_dout)
          0: begin
            if (r_wb_dat_i_dout == 8'hFF) begin
              counter_recv_bytes_up = 1;
            end else begin
              counter_recv_bytes_rst = 1;
              next_state = END_STATE;
            end
          end
          1: begin
            if (r_wb_dat_i_dout == 8'hFF) begin
              counter_recv_bytes_up = 1;
              r_checksum_cl = 1;
            end else begin
              counter_recv_bytes_rst = 1;
              next_state = END_STATE;
            end
          end
          2: begin
            r_ctrl_cl = 1;
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
            r_checksum_w = 1;
            //register ID value
            r_id_w = 1;
            r_id_dat_i = r_wb_dat_i_dout;
          end
          3: begin
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
            r_checksum_w = 1;
            //register LENGHT value
            r_len_w = 1;
            r_len_dat_i = r_wb_dat_i_dout;
            //register LENGHT-2 in counter param
            counter_param_rst = 1;
            counter_param_din = r_wb_dat_i_dout - 2;
          end
          4: begin
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
            r_checksum_w = 1;
            //register INST value
            r_inst_w = 1;
            r_inst_dat_i = r_wb_dat_i_dout;
          end
        endcase
      end

      PARAMETERS_BYTE_INST: begin
        next_state = SEND_BYTE_0;
        r_jmp_state_i = SWITCH_PROCCESS_BYTE_INST;
        r_jmp_state_w = 1;
        counter_recv_bytes_up = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
        r_checksum_w = 1;
        counter_param_down = 1;
        //register param
        r_param_w[counter_recv_bytes_dout-5] = 1;
        r_param_din[counter_recv_bytes_dout-5] = r_wb_dat_i_dout;
      end

      CHECK_CHECKSUM: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SEND_DATA_ADDR;
        next_state = CHEKSUM_1;
        counter_recv_bytes_rst = 1;
        //if (r_wb_dat_i_dout != r_checksum_output) begin
        //
        //end
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
        r_resp_err_w = 1;
        r_resp_err_dat_i = r_wb_dat_i_dout;
        next_state = GET_DATA_UART_0;
      end
      LOOP_RSP: begin
        if (counter_len_inst_dout == 1) begin
          next_state = CHECK_INST_MOVE;
          if (checksum_value != r_wb_dat_i_dout) begin
            next_state = END_STATE;
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

      CHECK_INST_MOVE: begin
        if (r_inst_dat_o == INST_WRITE_DATA && r_resp_err_dat_o == 0 && r_param_dout[0]==ADDR_GOAL_POSITION_L) begin
          next_state = WAIT_SERVO_FOR_GOAL_POS;
          counter_recv_bytes_rst = 1;
          r_checksum_cl = 1;
        end else begin
          next_state = SEND_INST_0;
        end
      end

      WAIT_SERVO_FOR_GOAL_POS: begin
        next_state = WAIT_SERVO_FOR_GOAL_POS;
        counter_recv_bytes_up = 1;
        if (counter_recv_bytes_dout == 8'h80) begin
          counter_recv_bytes_rst = 1;
          next_state = WAIT_SERVO_FOR_GOAL_POS_0;
        end
      end

      WAIT_SERVO_FOR_GOAL_POS_0: begin

        next_state = SEND_DIRECT_DATA_0;
        r_jmp_state_i = WAIT_SERVO_FOR_GOAL_POS_0;
        r_jmp_state_w = 1;
        counter_recv_bytes_up = 1;
        case (counter_recv_bytes_dout)
          0: begin
            r_wb_dat_i_din = 8'hFF;
            r_wb_dat_i_w   = 1;
          end
          1: begin
            r_wb_dat_i_din = 8'hFF;
            r_wb_dat_i_w   = 1;
          end
          2: begin
            r_wb_dat_i_din = r_id_dat_o;
            r_wb_dat_i_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_id_dat_o;
            r_checksum_w = 1;
          end
          3: begin
            r_wb_dat_i_din = 8'h04;
            r_wb_dat_i_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + 8'h04;
            r_checksum_w = 1;
          end
          4: begin
            r_wb_dat_i_din = INST_READ_DATA;
            r_wb_dat_i_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + INST_READ_DATA;
            r_checksum_w = 1;
          end
          5: begin
            r_wb_dat_i_din = ADDR_PRESENT_POSITION_L;
            r_wb_dat_i_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + ADDR_PRESENT_POSITION_L;
            r_checksum_w = 1;
          end
          6: begin
            r_wb_dat_i_din = 8'h2;
            r_wb_dat_i_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + 8'h2;
            r_checksum_w = 1;
          end
          7: begin
            r_wb_dat_i_din = ~(r_checksum_dat_o);
            r_wb_dat_i_w   = 1;
          end
          8: begin
            r_jmp_state_w = 0;
            r_checksum_cl = 1;
            next_state = WAIT_FOR_UART_TX_EMPTY_0;
            counter_recv_bytes_rst = 1;
          end
        endcase
      end
      
      WAIT_FOR_UART_TX_EMPTY_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CTRL_UART;  //ask for how many bytes are in rx fifo
        next_state = WAIT_FOR_UART_TX_EMPTY_1;

        

      end
      
      WAIT_FOR_UART_TX_EMPTY_1: begin
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o = 0;
        wb_sel_o = 0;

        if (wb_ack_i == 1) begin
          r_jmp_state_i = WAIT_FOR_UART_TX_EMPTY_2;
          r_jmp_state_w = 1;
          r_wb_dat_i_w = 1;
          next_state = WAIT_NEG_ACK_0;
        end

      end
      WAIT_FOR_UART_TX_EMPTY_2: begin
        timeout_rst = 0;
        if (r_wb_dat_i_dout[4] == 0) begin
          r_jmp_state_w = 1;
            r_jmp_state_i = WAIT_SERVO_FOR_GOAL_POS_1;
            r_checksum_cl = 1;
            next_state = GET_DATA_UART_0;
            counter_recv_bytes_rst = 1;
        end else begin
          next_state = WAIT_FOR_UART_TX_EMPTY_0;
        end

      end

      WAIT_SERVO_FOR_GOAL_POS_1: begin
        next_state = GET_DATA_UART_0;
        r_jmp_state_w = 1;
        r_jmp_state_i = WAIT_SERVO_FOR_GOAL_POS_1;
        counter_recv_bytes_up = 1;
        case (counter_recv_bytes_dout)
          0: begin
            //FF
          end
          1: begin
            //FF
          end
          2: begin
            //ID
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;

          end
          3: begin
            //LEN
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
          end
          4: begin
            //ERR
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
          end
          5: begin
            //PARAM1
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
            if ((r_wb_dat_i_dout < (r_param_dout[1]+10)) && (r_wb_dat_i_dout > (r_param_dout[1]-10))) begin
              // in position
              r_ctrl_w = 1;
              r_ctrl_dat_i = r_ctrl_dat_o | (1 << CTRL_POSITION_L_REACHED);
            end
          end
          6: begin
            //PARAM1
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_wb_dat_i_dout;
            if (r_wb_dat_i_dout == r_param_dout[2]) begin
              // in position
              r_ctrl_w = 1;
              r_ctrl_dat_i = r_ctrl_dat_o | (1 << CTRL_POSITION_H_REACHED);
            end
          end
          7: begin
            //CHECKSUM
            if (r_wb_dat_i_dout != checksum_value) begin
              next_state = WAIT_SERVO_FOR_GOAL_POS_2;  //END_STATE;
              r_ctrl_dat_i = 0;
              r_ctrl_w = 1;
            end else begin
              next_state = WAIT_SERVO_FOR_GOAL_POS_2;
            end
            r_jmp_state_w = 0;
            counter_recv_bytes_rst = 1;
          end
        endcase
      end

      WAIT_SERVO_FOR_GOAL_POS_2: begin
        r_checksum_cl = 1;
        next_state = CHECK_INST_MOVE;
        if (r_ctrl_dat_o & (1 << CTRL_POSITION_H_REACHED)) begin
          if (r_ctrl_dat_o & (1 << CTRL_POSITION_L_REACHED)) begin
            next_state = SEND_INST_0;
          end
        end
      end





      GET_DATA_UART_0: begin
        timeout_rst = 0;
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_CTRL_UART;  //ask for how many bytes are in rx fifo
        next_state = GET_DATA_UART_1;

        if (timeout_dout == 0) begin
          next_state = CHECK_INST_MOVE;
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
        if (r_wb_dat_i_dout[3:0] == 0) begin
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
        /*
        if (timeout_dout == 0) begin
          next_state = SEND_INST_0;
        end
	*/

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
          r_jmp_state_w = 1;  //(r_ctrl_dat_o & (1 << CTRL_NOT_READ_AFTER_SEND)) ? 0 : 1;
          r_jmp_state_i = READ_BYTE_0;
          next_state = WAIT_NEG_ACK_0;
        end

      end

      SEND_DIRECT_DATA_0: begin
        r_wb_adr_o_w = 1;
        r_wb_adr_o_din = UART_SEND_DATA_ADDR;
        next_state = SEND_DIRECT_DATA_1;
      end
      SEND_DIRECT_DATA_1: begin
        wb_dat_o = r_wb_dat_i_dout;
        wb_cyc_o = 1;
        wb_stb_o = 1;
        wb_we_o  = 1;
        wb_sel_o = {(WB_DATA >> 3) {1'b1}};

        if (wb_ack_i == 1) begin
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
        /*
        if (timeout_dout == 0) begin
          timeout_rst = 1;
          next_state  = SEND_INST_0;
        end
	*/
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
