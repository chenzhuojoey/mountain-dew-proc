module cb (clk, reset, move_tail, tail_new, din1_en, din2_en, dout1_req, dout2_req, 
			din1, din2, dout1, dout2, full, full_almost);

	//synopsys template

module cb (clk, reset, move_tail, tail_new, din1_en, din2_en, dout1_req, dout2_req, 
			din1, din2, dout1, dout2, full, full_almost);

	parameter CB_LENGTH = 8;

  input clk, reset, move_tail, din1_en, din2_en, dout1_req, dout2_req;
	input [ROB_IDX-1:0] tail_new;
	input [CB_WIDTH-1:0] din1, din2;
	output reg full, full_almost;
	output reg [CB_WIDTH-1:0] dout1, dout2;

	// internal regs
	reg [ROB_IDX-1:0] head, tail;
	reg [CB_WIDTH-1:0] data [CB_LENGTH-1:0];
	reg [CB_WIDTH-1:0] next_data1, next_data2;
	reg [ROB_IDX-1:0] next_head, next_tail;

	// i/o counter
	reg [ROB_IDX:0] iocount;
	wire [ROB_IDX:0] next_iocount;
	reg [1:0] incount, outcount;
	reg empty, empty_almost;

	// purely combinational
	wire [ROB_IDX-1:0] tail_p1, tail_p2, head_p1, head_p2, cur_size;
	wire next_full, next_full_almost, next_empty, next_empty_almost;
	
	assign tail_p1 = tail + 1'd1;
	assign tail_p2 = tail + 2'd2;
	assign head_p1 = head + 1'd1;
	assign head_p2 = head + 2'd2;
	
	assign cur_size = (next_tail>=next_head)? (next_tail - next_head) : (next_tail + CB_LENGTH - next_head);
	assign next_iocount = (move_tail)? cur_size : iocount + incount - outcount;
	assign next_full = next_iocount == CB_LENGTH;
	assign next_full_almost = next_iocount == (CB_LENGTH-1);
	assign next_empty = next_iocount == 0;
	assign next_empty_almost = next_iocount == 1;

	always @* begin
		// default cases
		next_data1 = data[tail];
		next_data2 = data[tail_p1];
		next_head = head;
		next_tail = tail;
		incount = 2'd0;
		outcount = 2'd0;

		// deal with tail and data in
		if (move_tail) begin
			next_tail = tail_new;
		end else begin
			if (din1_en && !full) begin
				next_tail = tail_p1;
				next_data1 = din1;
				incount = 2'd1;
				if (din2_en && !full_almost) begin
					next_tail = tail_p2;
					next_data2 = din2;
					incount = 2'd2;
				end
			end
		end

		// deal with head and data out
		if (dout1_req && !empty) begin
			next_head = head_p1;
			dout1 = data[head];
			outcount = 2'd1;
			if (dout2_req && !empty_almost) begin
				next_head = head_p2;
				dout2 = data[head_p1];
				outcount = 2'd2;
			end
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			head 					<= `SD {ROB_IDX{1'b0}};
			tail 					<= `SD {ROB_IDX{1'b0}};
			iocount 			<= `SD {ROB_IDX+1{1'b0}};
			full 					<= `SD 1'b0;
			full_almost 	<= `SD 1'b0;
			empty					<= `SD 1'b0;
			empty_almost	<= `SD 1'b0;
		end else begin
			data[tail]		<= `SD next_data1;
			data[tail_p1] <= `SD next_data2;
			head 					<= `SD next_head;
			tail					<= `SD next_tail;
			iocount 			<= `SD next_iocount;
			full 					<= `SD next_full;
			full_almost 	<= `SD next_full_almost;
			empty					<= `SD next_empty;
			empty_almost	<= `SD next_empty_almost;
		end
	end

endmodule
