module rob (clk, reset, 
						// ready/valid indicators for data in/out
						din1_rdy, din2_rdy, dout1_valid, dout2_valid,  
						// allocate requests
						din1_req, din2_req,
						// update requests
						up1_req, up2_req,
						// incoming values
						ir_in1, ir_in2, npc_in1, npc_in2, pdest_in1, pdest_in2, ba_pd_in1, ba_pd_in2, bt_pd_in1, bt_pd_in2,
						// values that gets updated
						ba_ex_in1, ba_ex_in2, bt_ex_in1, bt_ex_in2, bt_addr_in1, bt_addr_in2, 
						// rob indices for updates
						rob_idx_in1, rob_idx_in2,
						// allocated rob indices
						rob_idx_out1, rob_idx_out2,
						// output values at retirement
						ir_out1, ir_out2, npc_out1, npc_out2, pdest_out1, pdest_out2
						);

  input clk, reset, din1_req, din2_req;
	input [31:0] ir_in1, ir_in2;
	input [63:0] npc_in1, npc_in2;
	input [`PRF_IDX-1:0] pdest_in1, pdest_in2;
	input btaken_in1, btaken_in2;
	input [63:0] bt_addr_in1, bt_addr_in2;
	input [`ROB_IDX-1:0] rob_idx_in1, rob_idx_in2;
	
	output din1_rdy, din2_rdy;
	output reg dout1_valid, dout2_valid;
	output [`ROB_IDX-1:0] rob_idx_out1, rob_idx_out2;
	output [`PRF_IDX-1:0] pdest_out1, pdest_out2;
	output [31:0] ir_out1, ir_out2;
	output [63:0] npc_out1, npc_out2;


  // Data input indicators for outside world
	assign din1_rdy = !full;
	assign din2_rdy = !full || !full_almost;

	assign rob_idx_out1 = tail;
	assign rob_idx_out2 = tail_p1;


	// Retiring decision
	wire retire1, retire2;

	assign retire1 = !empty && data_rdy[head];
	assign retire2 = !empty_almost && retire1 && data_rdy[head_p1];
	
	// Branch miss
	reg branch_miss, move_tail;
	reg tail_new;

	// ===================================================
	// Duplicate cb functionality for things to be updated
	// ===================================================
	reg [63-1:0] 			data_ba_ex [`ROB_SZ-1:0];
	reg [`ROB_SZ-1:0] data_bt_ex;
	reg [`ROB_SZ-1:0] data_rdy;

	reg [63-1:0] next_data_ba_ex1, next_data_ba_ex2;
	reg next_data_bt_ex1, next_data_bt_ex2;
	reg next_data_rdy1, next_data_rdy2;


	reg [`ROB_IDX-1:0] next_head, next_tail;

	// i/o counter
	reg [`ROB_IDX:0] iocount;
	wire [`ROB_IDX:0] next_iocount;
	reg [1:0] incount, outcount;
	reg empty, empty_almost;

	// purely combinational
	wire [`ROB_IDX-1:0] tail_p1, tail_p2, head_p1, head_p2, cur_size;
	wire next_full, next_full_almost, next_empty, next_empty_almost;
	
	assign tail_p1 = tail + 1'd1;
	assign tail_p2 = tail + 2'd2;
	assign head_p1 = head + 1'd1;
	assign head_p2 = head + 2'd2;
	
	assign cur_size = (next_tail>=next_head)? (next_tail - next_head) : (next_tail + `ROB_SZ - next_head);
	assign next_iocount = (move_tail)? cur_size : iocount + incount - outcount;
	assign next_full = next_iocount == `ROB_SZ;
	assign next_full_almost = next_iocount == (`ROB_SZ-1);
	assign next_empty = next_iocount == 0;
	assign next_empty_almost = next_iocount == 1;

	always @* begin
		// default cases for data
		next_data_ba_ex1 = data_ba_ex[tail];
		next_data_ba_ex2 = data_ba_ex[tail_p1];
		next_data_bt_ex1 = data_bt_ex[tail];
		next_data_bt_ex2 = data_bt_ex[tail_p1];
		next_data_rdy1 = data_rdy[tail];
		next_data_rdy2 = data_rdy[tail_p1];
		
		// other default cases
		next_head = head;
		next_tail = tail;
		incount = 2'd0;
		outcount = 2'd0;
		dout1_valid = retire1;
		dout2_valid = retire2;
		branch_miss = 0;

		// deal with branch misses
		if (retire1) begin
			if ((data_bt_ex[head] != bt_pd_out1) || (data_ba_ex[head] != ba_pd_out1)) begin
				branch_miss = 1;
				dout2_valid = 0;	
				move_tail = 1;
				tail_new = next_head;
			end else if (retire2) begin
				if ((data_bt_ex[head_p1] != bt_pd_out2) || (data_ba_ex[head_p1] != ba_pd_out2)) begin
					branch_miss = 1;
					move_tail = 1;
					tail_new = next_head;
				end 
			end
		end


		// deal with tail and data in (allocate)
		if (move_tail) begin
			next_tail = tail_new;
		end else begin
			if (din1_req && !full) begin
				next_tail = tail_p1;
				incount = 2'd1;

				next_data_ba_ex1 = {64{1'b0}};
				next_data_bt_ex1 = 1'b0;
				next_data_rdy1 = 1'b0;

				if (din2_req && !full_almost) begin
					next_tail = tail_p2;
					incount = 2'd2;
					
					next_data_ba_ex2 = {64{1'b0}};
					next_data_bt_ex2 = 1'b0;
					next_data_rdy2 = 1'b0;

				end
			end
		end

		// deal with head and data out
		if (retire1 && !empty) begin
			next_head = head_p1;
			//dout1 = data[head];
			outcount = 2'd1;
			if (retire2 && !empty_almost) begin
				next_head = head_p2;
				//dout2 = data[head_p1];
				outcount = 2'd2;
			end
		end


	end // always @*


	// ===================================================
	// Sequential Block
	// ===================================================
	always @(posedge clk) begin
		if (reset) begin
			head 					<= `SD {`ROB_IDX{1'b0}};
			tail 					<= `SD {`ROB_IDX{1'b0}};
			iocount 			<= `SD {`ROB_IDX+1{1'b0}};
			full 					<= `SD 1'b0;
			full_almost 	<= `SD 1'b0;
			empty					<= `SD 1'b0;
			empty_almost	<= `SD 1'b0;

		end else begin
			// data allocation
			data_ba_ex[tail]			<= `SD next_data_ba_ex1;
			data_ba_ex[tail_p1]		<= `SD next_data_ba_ex2;
			data_bt_ex[tail]			<= `SD next_data_bt_ex1;
			data_bt_ex[tail_p1]		<= `SD next_data_bt_ex2;
			data_rdy[tail]				<= `SD next_data_rdy1;
			data_rdy[tail_p1]			<= `SD next_data_rdy2;

			// data updates
			if (up1_req) begin
				data_ba_ex[rob_idx_in1] <= `SD ba_ex_in1;
				data_bt_ex[rob_idx_in1] 	<= `SD bt_ex_in1;
				data_rdy[rob_idx_in1] 		<= `SD 1'b1;
				if (up2_req) begin
					data_ba_ex[rob_idx_in2] <= `SD ba_ex_in2;
					data_bt_ex[rob_idx_in2] 	<= `SD bt_ex_in2;
					data_rdy[rob_idx_in2] 		<= `SD 1'b1;
				end
			end

			head 					<= `SD next_head;
			tail					<= `SD next_tail;
			iocount 			<= `SD next_iocount;
			full 					<= `SD next_full;
			full_almost 	<= `SD next_full_almost;
			empty					<= `SD next_empty;
			empty_almost	<= `SD next_empty_almost;
		end
	end

	// ===================================================
	// Circular buffers for entries not awaiting updates
	// ===================================================

	// Circular buffer for IR
	cb #(.CB_IDX(`ROB_IDX), .CB_WIDTH(32), .CB_LENGTH(`ROB_SZ)) cb_ir (
		.clk(clk), .reset(reset),	.move_tail(move_tail), .tail_new(tail_new), 
		.din1_en(din1_req), .din2_en(din2_req), .dout1_req(retire1), .dout2_req(retire2),
		.din1(ir_in1), .din2(ir_in2), .dout1(ir_out1), .dout2(ir_out2), 
		.full(), .full_almost(), .head(), .tail());

	// Circular buffer for NPC
	cb #(.CB_IDX(`ROB_IDX), .CB_WIDTH(64), .CB_LENGTH(`ROB_SZ)) cb_npc (
		.clk(clk), .reset(reset),	.move_tail(move_tail), .tail_new(tail_new), 
		.din1_en(din1_req), .din2_en(din2_req), .dout1_req(retire1), .dout2_req(retire2),
		.din1(npc_in1), .din2(npc_in2), .dout1(npc_out1), .dout2(npc_out2), 
		.full(), .full_almost(), .head(), .tail());

	// Circular buffer for PDEST_IDX
	cb #(.CB_IDX(`ROB_IDX), .CB_WIDTH(32), .CB_LENGTH(`ROB_SZ)) cb_pdest (
		.clk(clk), .reset(reset),	.move_tail(move_tail), .tail_new(tail_new), 
		.din1_en(din1_req), .din2_en(din2_req), .dout1_req(retire1), .dout2_req(retire2),
		.din1(pdest_in1), .din2(pdest_in2), .dout1(pdest_out1), .dout2(pdest_out2), 
		.full(), .full_almost(), .head(), .tail());

	// Circular buffer for Predicted Branch Address
	cb #(.CB_IDX(`ROB_IDX), .CB_WIDTH(64), .CB_LENGTH(`ROB_SZ)) cb_ba_pd (
		.clk(clk), .reset(reset),	.move_tail(move_tail), .tail_new(tail_new), 
		.din1_en(din1_req), .din2_en(din2_req), .dout1_req(retire1), .dout2_req(retire2),
		.din1(ba_pd_in1), .din2(ba_pd_in2), .dout1(ba_pd_out1), .dout2(ba_pd_out2), 
		.full(), .full_almost(), .head(), .tail());

	// Circular buffer for Predicted Branch Direction
	cb #(.CB_IDX(`ROB_IDX), .CB_WIDTH(1), .CB_LENGTH(`ROB_SZ)) cb_bt_pd (
		.clk(clk), .reset(reset),	.move_tail(move_tail), .tail_new(tail_new), 
		.din1_en(din1_req), .din2_en(din2_req), .dout1_req(retire1), .dout2_req(retire2),
		.din1(bt_pd_in1), .din2(bt_pd_in2), .dout1(bt_pd_out1), .dout2(bt_pd_out2), 
		.full(), .full_almost(), .head(), .tail());

endmodule