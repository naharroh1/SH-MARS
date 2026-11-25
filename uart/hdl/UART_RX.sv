/**
 * File              : UART_RX.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 02.04.2025
 * Last Modified Date: 02.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */

module UART_RX #(
    parameter F_MHZ   = 100,
    parameter BAUDIOS = 1000000
) (
    input clk,
    input rst,
    input rx,
    output logic active,
    output logic rx_done,
    output [2:0] estado,
    output [7:0] rx_byte
);

  localparam N_CLK_SAMPLING = (F_MHZ * 1000000) / BAUDIOS;
  //register for rx_byte
  logic r_rx_byte_load;
  logic r_rx_byte_cl;
  logic r_rx_byte_right;
  shift_register #(
      .DATA_WIDTH(8)
  ) r_rx_byte (
      .clk(clk),
      .cl(r_rx_byte_cl),
      .load(r_rx_byte_load),
      .shift_left(0),
      .shift_right(r_rx_byte_right),
      .input_bit(rx),
      .din(8'b0),
      .output_bit(),
      .dout(rx_byte)
  );

  //counter for sampling
  logic sampling_counter_rst;
  logic sampling_counter_up;
  logic [$clog2(N_CLK_SAMPLING)-1:0] sampling_counter_dout;
  counter #(
      .DATA_WIDTH($clog2(N_CLK_SAMPLING))
  ) sampling_counter (
      .clk (clk),
      .rst (sampling_counter_rst),
      .up  (sampling_counter_up),
      .down(0),
      .din (0),
      .dout(sampling_counter_dout)
  );

  //counter for bits
  logic bits_counter_rst;
  logic bits_counter_up;
  logic [2:0] bits_counter_dout;
  counter #(
      .DATA_WIDTH(3)
  ) bits_counter (
      .clk (clk),
      .rst (bits_counter_rst),
      .up  (bits_counter_up),
      .down(0),
      .din (0),
      .dout(bits_counter_dout)
  );
  
  logic jump_reg_cl,jump_reg_w;
  logic [2:0] jump_reg_din,jump_reg_dout;
  
  register #(.DATA_WIDTH(2)) jump_reg(
     .clk(clk),
     .cl(jump_reg_cl),
     .w(jump_reg_w),
     .din(jump_reg_din),
     .dout(jump_reg_dout)
  );

  logic [2:0] current_state, next_state;
  localparam IDLE = 0;
  localparam START_BIT = 1;
  localparam DATA_BITS = 2;
  localparam STOP_BITS = 3;
  localparam WAIT_SAMPLING = 4;

  assign estado = current_state;

  always_comb begin
    //default values
    next_state = current_state;
    r_rx_byte_cl = 0;
    r_rx_byte_load = 0;
    r_rx_byte_right = 0;
    sampling_counter_up = 0;
    sampling_counter_rst = 0;
    bits_counter_up = 0;
    bits_counter_rst = 0;
    active = 0;
    rx_done = 0;
    jump_reg_w = 0;
    jump_reg_cl = 0;
    jump_reg_din = 0;

    case (current_state)
      IDLE: begin
        sampling_counter_rst = 1;
        bits_counter_rst = 1;
        if (rx == 0) begin
          next_state   = START_BIT;
          r_rx_byte_cl = 1;
        end
      end
      START_BIT: begin
        active = 1;
        sampling_counter_up = 1;
        if (sampling_counter_dout == N_CLK_SAMPLING/2) begin
          jump_reg_din = DATA_BITS;
          jump_reg_w = 1;
          next_state = WAIT_SAMPLING;
          //sampling_counter_rst = 1;
        end else begin
          if (rx == 1) begin
            next_state = IDLE;
          end
        end

      end
      DATA_BITS: begin
        active = 1;
        sampling_counter_up = 1;
        if (sampling_counter_dout == N_CLK_SAMPLING/2) begin

          bits_counter_up = 1;
          //sampling_counter_rst = 1;
          r_rx_byte_right = 1;
          jump_reg_din = DATA_BITS;
          jump_reg_w = 1;
          next_state = WAIT_SAMPLING;

          if (bits_counter_dout == 7) begin
            next_state = STOP_BITS;
          end

        end

      end
      STOP_BITS: begin
        active = 1;
        sampling_counter_up = 1;
        if (sampling_counter_dout == N_CLK_SAMPLING-2) begin
          rx_done = 1;
          next_state = IDLE;
        end
     end
    
      WAIT_SAMPLING: begin
        active = 1;
        sampling_counter_up = 1;
        if(sampling_counter_dout == N_CLK_SAMPLING) begin
           sampling_counter_rst = 1;
           next_state = jump_reg_dout;
        end
      end


    endcase

  end

  always_ff @(posedge clk) begin
    if (rst) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end

  end
endmodule
