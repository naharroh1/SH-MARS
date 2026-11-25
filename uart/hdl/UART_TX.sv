/**
 * File              : UART_TX.sv
 * Author            : German C.Quiveu <germancq@dte.us.es>
 * Date              : 04.04.2025
 * Last Modified Date: 04.04.2025
 * Last Modified By  : German C.Quiveu <germancq@dte.us.es>
 */
module UART_TX #(parameter F_MHZ = 100, parameter BAUDIOS=1000000) (
	input clk,
	input rst,
	input start,
	input [7:0] byte_in,
	output [2:0] estado,
	output logic active,
	output logic tx,
	output logic done
	
);
	

 localparam N_CLK_SAMPLING = (F_MHZ * 1000000) / BAUDIOS;
 //register for rx_byte
 logic r_tx_byte_load;
 logic r_tx_byte_cl;
 logic r_tx_byte_right;
 logic r_tx_output_bit;
 shift_register #(.DATA_WIDTH(8)) r_tx_byte(
	 .clk(clk),
	 .cl(r_tx_byte_cl),
	 .load(r_tx_byte_load),
	 .shift_left(0),
	 .shift_right(r_tx_byte_right),
	 .input_bit(0),
	 .din(byte_in),
	 .output_bit(r_tx_output_bit),
	 .dout()
	 );

//counter for sampling
logic sampling_counter_rst;
logic sampling_counter_up;
logic [$clog2(N_CLK_SAMPLING)-1:0] sampling_counter_dout;
counter #(.DATA_WIDTH($clog2(N_CLK_SAMPLING))) sampling_counter(
	.clk(clk),
	.rst(sampling_counter_rst),
	.up(sampling_counter_up),
	.down(0),
	.din(0),
	.dout(sampling_counter_dout));

//counter for bits
logic bits_counter_rst;
logic bits_counter_up;
logic [2:0] bits_counter_dout;
counter #(.DATA_WIDTH(3)) bits_counter(
	.clk(clk),
	.rst(bits_counter_rst),
	.up(bits_counter_up),
	.down(0),
	.din(0),
	.dout(bits_counter_dout));

logic [2:0] current_state, next_state;
 localparam IDLE = 0;
 localparam START_BIT = 1;
 localparam DATA_BITS = 2;
 localparam STOP_BITS = 3;
 localparam DONE = 4;

 assign estado = current_state;

 always_comb begin  
	 //default values
	 next_state = current_state;
	 r_tx_byte_cl = 0;
	 r_tx_byte_load = 0;
	 r_tx_byte_right = 0;
	 sampling_counter_up = 0;
	 sampling_counter_rst = 0;
	 bits_counter_up = 0;
	 bits_counter_rst = 0;
	 active = 0;
	 tx = r_tx_output_bit;
	 done = 0;

	 case (current_state)
		 IDLE: begin
			 tx=1;
			 sampling_counter_rst = 1;
			 bits_counter_rst = 1;
			 if(start == 1) begin
			 	next_state = START_BIT;
			 	r_tx_byte_load = 1;
			 end
		 end
		 START_BIT: begin
			 active = 1;
			 tx = 0;
			 sampling_counter_up = 1;
			 if(sampling_counter_dout == N_CLK_SAMPLING-2) begin
			 	next_state = DATA_BITS;
				sampling_counter_rst = 1;
				r_tx_byte_right = 1;
			 end
		 end
		 DATA_BITS: begin
			 active = 1;
			 sampling_counter_up = 1;
			 if(sampling_counter_dout == N_CLK_SAMPLING-2) begin

				bits_counter_up = 1;
				sampling_counter_rst = 1;
				r_tx_byte_right = 1;

				if(bits_counter_dout == 7) begin
					next_state = STOP_BITS;
				end
			 	
			 end
		 	
		 end
		 STOP_BITS: begin
			 tx=1;
			 active = 1;
			 sampling_counter_up = 1;
			 if(sampling_counter_dout == N_CLK_SAMPLING-2) begin
			 	next_state = DONE;
			 end
		 	
		 end
		 DONE: begin
			tx = 1;
		 	done = 1;
			next_state=IDLE;
		 end
		 	
	 	
	 endcase
 	
 end

 always_ff @(posedge clk) begin 
	 if(rst) begin
	 	current_state <= IDLE;
	 end
	 else begin
	 	current_state <= next_state;
	 end
 	
 end
endmodule
