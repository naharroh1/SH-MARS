/**
 * File              : shaper.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 15.05.2025
 * Last Modified Date: 15.05.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module shaper #(
    parameter FILE_MEM = "memory.mem",
    parameter WB_DATA_WIDTH = 32,
    parameter WB_ADDR_DIR = 8,
    parameter MAX_NUM_PARAMETERS_ALLOWED = 8
) (
    input                                  wb_clk,
    input                                  wb_rst,
    //wishbone interface
    input        [$clog2(WB_ADDR_DIR)-1:0] wb_adr_i,
    input        [      WB_DATA_WIDTH-1:0] wb_dat_i,
    input                                  wb_we_i,
    input                                  wb_cyc_i,
    input                                  wb_stb_i,
    input        [ (WB_DATA_WIDTH>>3)-1:0] wb_sel_i,
    input        [                    2:0] wb_cti_i,
    input        [                    1:0] wb_bte_i,
    output logic                           wb_ack_o,
    output logic                           wb_err_o,
    output                                 wb_rty_o,
    output       [      WB_DATA_WIDTH-1:0] wb_dat_o,

    output [7:0] debug_state
);

  assign debug_state = current_state;

  localparam SEND_DATA_TO_SHAPER = 0;
  localparam SEND_DATA_FROM_SHAPER = 1;
  localparam CTRL_SHAPER = 2;
  localparam MOD_MEM = 3;

  //cte values
  assign wb_rty_o = 0;

  logic [WB_DATA_WIDTH-1:0] bank_register[WB_ADDR_DIR-1:0];

  genvar i;
  //register data from wishbone bus
  generate
    for (i = 0; i < (WB_ADDR_DIR); i = i + 1) begin
      register #(
          .DATA_WIDTH(WB_DATA_WIDTH)
      ) r_banks (
          .clk(wb_clk),
          .cl(wb_rst),
          .w(wb_adr_i == i ? (wb_stb_i & wb_we_i) : 0),
          .din(wb_dat_i),
          .dout(bank_register[i])
      );
    end
  endgenerate



  logic r_data_w;
  logic [WB_DATA_WIDTH-1:0] wb_data;
  //register data to wishbone bus
  register #(
      .DATA_WIDTH(WB_DATA_WIDTH)
  ) r_data (
      .clk(wb_clk),
      .cl(wb_rst),
      .w(r_data_w),
      .din(wb_data),
      .dout(wb_dat_o)
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

  logic servo_mem_r_w;
  logic [5:0] servo_mem_addr;
  logic [7:0] servo_mem_din, servo_mem_dout;
  logic servo_mem_reset_values;
  memory_module_init #(
      .ADDR(6),
      .DATA_WIDTH(8),
      .FILE_MEM(FILE_MEM)
  ) servo_mem (
      .clk(wb_clk),
      .r_w(servo_mem_r_w),
      .addr(servo_mem_addr),
      .din(servo_mem_din),
      .dout(servo_mem_dout),
      .reset_values(servo_mem_reset_values)
  );

  logic r_checksum_cl;
  logic r_checksum_w;
  logic [7:0] r_checksum_dat_i, r_checksum_dat_o;
  logic [7:0] r_checksum_output;
  assign r_checksum_output = ~r_checksum_dat_o;
  register #(
      .DATA_WIDTH(8)
  ) r_checksum (
      .clk(wb_clk),
      .cl(r_checksum_cl),
      .w(r_checksum_w),
      .din(r_checksum_dat_i),
      .dout(r_checksum_dat_o)
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

  localparam INPUT_VOLTAGE_ERROR = 0;
  localparam ANGLE_LIMIT_ERROR = 1;
  localparam OVERHEATING_ERROR = 2;
  localparam RANGE_ERROR = 3;
  localparam CHECKSUM_ERROR = 4;
  localparam OVERLOAD_ERROR = 5;
  localparam INSTRUCTION_ERROR = 6;
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

  localparam INST_PING = 1;
  localparam INST_READ_DATA = 2;
  localparam INST_WRITE_DATA = 3;
  localparam INST_REG_WRITE = 4;
  localparam INST_ACTION = 5;
  localparam INST_RESET = 6;
  localparam INST_SYNC_WRITE = 8'h83;


  logic instruction_mod_stack_rst;
  logic [7:0] instruction_mod_stack_data_i;
  logic [7:0] instruction_mod_stack_data_o;
  logic instruction_mod_stack_push;
  logic instruction_mod_stack_pop;
  logic instruction_mod_stack_empty;
  logic instruction_mod_stack_full;
  logic [$clog2(MAX_NUM_PARAMETERS_ALLOWED+6):0] instruction_mod_stack_sp_index;
  stack #(
      .FIFO_LIFO(0),
      .DEPTH(MAX_NUM_PARAMETERS_ALLOWED + 6),
      .WIDTH(8)
  ) instruction_mod_stack (
      .clk(wb_clk),
      .rst(instruction_mod_stack_rst),
      .data_i(instruction_mod_stack_data_i),
      .data_o(instruction_mod_stack_data_o),
      .push(instruction_mod_stack_push),
      .pop(instruction_mod_stack_pop),
      .empty(instruction_mod_stack_empty),
      .full(instruction_mod_stack_full),
      .sp_index(instruction_mod_stack_sp_index)
  );


  localparam CTRL_INST_READY = 0;
  localparam CTRL_NO_INST = 1;
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


  logic [4:0] current_state, next_state;

  localparam RST_STATE = 0;
  localparam IDLE = 1;
  localparam READ_INST_OP_0 = 2;
  localparam READ_INST_OP_1 = 3;
  localparam CTRL_SHAPER_OP_0 = 4;
  localparam SWITCH_PROCCESS_BYTE_INST = 5;
  localparam CHECK_BYTE_INST = 6;
  localparam PARAMETERS_BYTE_INST = 7;
  localparam CHECK_CHECKSUM = 8;
  localparam CHECK_INST_0 = 9;
  localparam CHECK_INST_1 = 10;
  localparam BUILD_INST_PREAMBULE_0 = 11;
  localparam BUILD_INST_PREAMBULE_1 = 12;
  localparam BUILD_INST_ID = 13;
  localparam BUILD_INST_LEN = 14;
  localparam BUILD_INST_INST = 15;
  localparam BUILD_INST_PARAMS = 16;
  localparam BUILD_MOD_PARAM = 17;
  localparam BUILD_INST_CHECKSUM = 18;
  localparam END_OP = 19;
  localparam MOD_MEM_OP_0 = 20;


  logic [31:0] j;

  always_comb begin
    next_state = current_state;

    servo_mem_r_w = 0;
    servo_mem_addr = 0;
    servo_mem_din = 0;
    servo_mem_reset_values = 0;

    r_checksum_cl = 0;
    r_checksum_w = 0;
    r_checksum_dat_i = 0;

    r_id_cl = 0;
    r_id_w = 0;
    r_id_dat_i = 0;

    r_len_cl = 0;
    r_len_w = 0;
    r_len_dat_i = 0;

    r_inst_cl = 0;
    r_inst_w = 0;
    r_inst_dat_i = 0;

    r_resp_err_cl = 0;
    r_resp_err_w = 0;
    r_resp_err_dat_i = 0;

    r_ctrl_w = 0;
    r_ctrl_cl = 0;
    r_ctrl_dat_i = 0;

    counter_recv_bytes_rst = 0;
    counter_recv_bytes_up = 0;

    counter_param_din = 0;
    counter_param_rst = 0;
    counter_param_down = 0;

    instruction_mod_stack_rst = 0;
    instruction_mod_stack_pop = 0;
    instruction_mod_stack_push = 0;
    instruction_mod_stack_data_i = 0;

    r_data_w = 0;

    wb_err_o = 0;
    wb_ack_o = 0;

    wb_data = 0;

    for (j = 0; j < MAX_NUM_PARAMETERS_ALLOWED; j++) begin
      r_param_w[j]   = 0;
      r_param_cl[j]  = 0;
      r_param_din[j] = 0;
    end

    case (current_state)
      RST_STATE: begin
        r_checksum_cl = 1;
        r_id_cl = 1;
        r_len_cl = 1;
        r_inst_cl = 1;
        r_resp_err_cl = 1;
        counter_recv_bytes_rst = 1;
        counter_param_rst = 1;
        instruction_mod_stack_rst = 1;
        r_ctrl_cl = 1;
        for (j = 0; j < MAX_NUM_PARAMETERS_ALLOWED; j++) begin
          r_param_cl[j] = 1;
        end
        next_state = IDLE;
      end
      IDLE: begin
        if (wb_stb_i & wb_cyc_i) begin
          case (wb_adr_i)
            SEND_DATA_TO_SHAPER: next_state = SWITCH_PROCCESS_BYTE_INST;
            SEND_DATA_FROM_SHAPER: next_state = READ_INST_OP_0;
            CTRL_SHAPER: next_state = CTRL_SHAPER_OP_0;
            MOD_MEM: next_state = MOD_MEM_OP_0;
            default: next_state = END_OP;
          endcase
        end
      end
      MOD_MEM_OP_0: begin
        servo_mem_addr = bank_register[MOD_MEM][7:0];
        servo_mem_din = bank_register[MOD_MEM][15:8];
        servo_mem_r_w = 1;
        next_state = END_OP;

      end
      READ_INST_OP_0: begin
        instruction_mod_stack_pop = 1;
        next_state = READ_INST_OP_1;
      end
      READ_INST_OP_1: begin
        if (instruction_mod_stack_empty == 1) begin
          r_ctrl_cl = 1;
        end
        r_data_w = 1;
        wb_data = instruction_mod_stack_data_o;
        next_state = END_OP;
      end
      CTRL_SHAPER_OP_0: begin
        r_data_w = 1;
        wb_data = r_ctrl_dat_o;
        next_state = END_OP;
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
        next_state = END_OP;
        case (counter_recv_bytes_dout)
          0: begin
            if (bank_register[SEND_DATA_TO_SHAPER] == 8'hFF) begin
              counter_recv_bytes_up = 1;
            end else begin
              counter_recv_bytes_rst = 1;
            end
          end
          1: begin
            if (bank_register[SEND_DATA_TO_SHAPER] == 8'hFF) begin
              counter_recv_bytes_up = 1;
              r_checksum_cl = 1;
            end else begin
              counter_recv_bytes_rst = 1;
            end
          end
          2: begin
            r_ctrl_cl = 1;
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + bank_register[SEND_DATA_TO_SHAPER];
            r_checksum_w = 1;
            //register ID value
            r_id_w = 1;
            r_id_dat_i = bank_register[SEND_DATA_TO_SHAPER];
          end
          3: begin
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + bank_register[SEND_DATA_TO_SHAPER];
            r_checksum_w = 1;
            //register LENGHT value
            r_len_w = 1;
            r_len_dat_i = bank_register[SEND_DATA_TO_SHAPER];
            //register LENGHT-2 in counter param
            counter_param_rst = 1;
            counter_param_din = bank_register[SEND_DATA_TO_SHAPER] - 2;
          end
          4: begin
            counter_recv_bytes_up = 1;
            r_checksum_dat_i = r_checksum_dat_o + bank_register[SEND_DATA_TO_SHAPER];
            r_checksum_w = 1;
            //register INST value
            r_inst_w = 1;
            r_inst_dat_i = bank_register[SEND_DATA_TO_SHAPER];
          end
        endcase
      end

      PARAMETERS_BYTE_INST: begin
        next_state = END_OP;
        counter_recv_bytes_up = 1;
        r_checksum_dat_i = r_checksum_dat_o + bank_register[SEND_DATA_TO_SHAPER];
        r_checksum_w = 1;
        counter_param_down = 1;
        //register param
        r_param_w[counter_recv_bytes_dout-5] = 1;
        r_param_din[counter_recv_bytes_dout-5] = bank_register[SEND_DATA_TO_SHAPER];
      end

      CHECK_CHECKSUM: begin
        next_state = CHECK_INST_0;
        counter_recv_bytes_rst = 1;
        if (bank_register[SEND_DATA_TO_SHAPER] != r_checksum_output) begin
          next_state = END_OP;
          r_ctrl_w = 1;
          r_ctrl_dat_i = r_ctrl_dat_o | CTRL_NO_INST;
        end
      end
      CHECK_INST_0: begin
        case (r_inst_dat_o)
          INST_WRITE_DATA: begin
            //modified
            next_state = BUILD_INST_PREAMBULE_0;
          end
          default: begin
            //no modified
            r_ctrl_w = 1;
            r_ctrl_dat_i = r_ctrl_dat_o | (1 << CTRL_NO_INST);
            next_state = BUILD_INST_PREAMBULE_0;
          end
        endcase
      end

      BUILD_INST_PREAMBULE_0: begin
        r_checksum_cl = 1;
        instruction_mod_stack_data_i = 8'hFF;
        instruction_mod_stack_push = 1;
        next_state = BUILD_INST_PREAMBULE_1;
      end
      BUILD_INST_PREAMBULE_1: begin
        instruction_mod_stack_data_i = 8'hFF;
        instruction_mod_stack_push = 1;
        next_state = BUILD_INST_ID;
      end
      BUILD_INST_ID: begin
        instruction_mod_stack_data_i = r_id_dat_o;
        instruction_mod_stack_push = 1;
        next_state = BUILD_INST_LEN;
        //checksum
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_id_dat_o;
      end
      BUILD_INST_LEN: begin
        instruction_mod_stack_data_i = r_len_dat_o;
        instruction_mod_stack_push = 1;
        next_state = BUILD_INST_INST;
        //checksum
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_len_dat_o;
      end

      BUILD_INST_INST: begin
        instruction_mod_stack_data_i = r_inst_dat_o;
        instruction_mod_stack_push = 1;
        next_state = BUILD_INST_PARAMS;
        //prepare param counter, suponemos siempre al menos un parametro
        if (r_len_dat_o == 2) begin
          next_state = BUILD_INST_CHECKSUM;
        end
        counter_param_rst = 1;
        counter_param_din = r_len_dat_o - 2;
        //checksum
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + r_inst_dat_o;
      end

      BUILD_INST_PARAMS: begin
        next_state = BUILD_INST_PARAMS;
        counter_param_down = 1;
        case (counter_param_dout)
          r_len_dat_o - 2: begin
            //param 0
            instruction_mod_stack_data_i = r_param_dout[r_len_dat_o-2-counter_param_dout];
            instruction_mod_stack_push = 1;
            r_checksum_w = 1;
            r_checksum_dat_i = r_checksum_dat_o + r_param_dout[r_len_dat_o-2-counter_param_dout];

          end
          0: begin
            //all params processed
            next_state = BUILD_INST_CHECKSUM;

          end

          default: begin
            //params from 1 to n
            //prepare memory to access modified params
            servo_mem_addr = r_param_dout[0] + (r_len_dat_o - 2 - counter_param_dout - 1);
            servo_mem_r_w = 0;

            //go to next state to write inst modified
            next_state = BUILD_MOD_PARAM;

          end
        endcase

      end
      BUILD_MOD_PARAM: begin
        next_state = BUILD_INST_PARAMS;
        servo_mem_r_w = 0;
        instruction_mod_stack_data_i = servo_mem_dout;
        instruction_mod_stack_push = 1;
        //checksum
        r_checksum_w = 1;
        r_checksum_dat_i = r_checksum_dat_o + servo_mem_dout;


      end
      BUILD_INST_CHECKSUM: begin
        instruction_mod_stack_data_i = r_checksum_output;
        instruction_mod_stack_push = 1;
        r_ctrl_w = 1;
        r_ctrl_dat_i = r_ctrl_dat_o | (1 << CTRL_INST_READY);
        next_state = END_OP;
      end

      END_OP: begin
        next_state = IDLE;
        wb_ack_o   = 1;
      end

    endcase

  end


  always_ff @(posedge wb_clk) begin
    if (wb_rst) begin
      current_state <= RST_STATE;
    end else begin
      current_state <= next_state;
    end
  end

endmodule
