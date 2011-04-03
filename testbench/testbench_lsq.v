`timescale 1ns/100ps
`define CB_IDX 3
`define CB_WIDTH 8 
`define CB_LENGTH 8 

// testbench works with length

module testbench;

  integer count, limbo, idx, NPC;  //TEST VARS

  reg clk, reset, din1_req, din2_req, dup1_req, dup2_req;
	reg [31:0] ir_in1, ir_in2;
	reg [63:0] npc_in1, npc_in2;
	reg [`PRF_IDX-1:0] pdest_in1, pdest_in2;
	reg [`ARF_IDX-1:0] adest_in1, adest_in2;
	reg bt_pd_in1, bt_pd_in2;
	reg [63:0] ba_pd_in1, ba_pd_in2;
	reg isbranch_in1, isbranch_in2;
	reg bt_ex_in1, bt_ex_in2;
	reg [63:0] ba_ex_in1, ba_ex_in2;
	reg [`ROB_IDX-1:0] rob_idx_in1, rob_idx_in2;
	
	reg  [63:0] proc2mem_addr;    // address for current command
	reg  [63:0] proc2mem_data;    // address for current command
	reg  [1:0]  proc2mem_command; // `BUS_NONE `BUS_LOAD or `BUS_STORE

	wire [3:0]  mem2proc_response;// 0 = can't accept, other=tag of transaction
	wire [63:0] mem2proc_data;    // data resulting from a load
	wire [3:0]  mem2proc_tag;     // 0 = no value, other=tag of transaction

	wire full, full_almost;
	wire dout1_valid, dout2_valid;
	wire [`ROB_IDX-1:0] rob_idx_out1, rob_idx_out2;
	wire [`PRF_IDX-1:0] pdest_out1, pdest_out2;
	wire [`ARF_IDX-1:0] adest_out1, adest_out2;
	wire [31:0] ir_out1, ir_out2;
	wire [63:0] npc_out1, npc_out2;
	wire branch_miss;
	wire [64-1:0] correct_target;
	wire [`SCALAR-1:0] isbranch_out;
	wire [`SCALAR-1:0] bt_out;
	wire [`SCALAR*64-1:0] ba_out;

	



	rob rob0 (clk, reset, 
						full, full_almost,
						dout1_valid, dout2_valid,
						din1_req, din2_req,
						dup1_req, dup2_req,
						ir_in1, ir_in2, npc_in1, npc_in2, pdest_in1, pdest_in2, adest_in1, adest_in2, ba_pd_in1, ba_pd_in2, bt_pd_in1, bt_pd_in2, isbranch_in1, isbranch_in2,
						ba_ex_in1, ba_ex_in2, bt_ex_in1, bt_ex_in2, 
						rob_idx_in1, rob_idx_in2,
						rob_idx_out1, rob_idx_out2,
						ir_out1, ir_out2, npc_out1, npc_out2, pdest_out1, pdest_out2, adest_out1, adest_out2,
						branch_miss, correct_target, 
						isbranch_out, bt_out, ba_out
						);
 mem mem0	( // Inputs
             clk,
             proc2mem_command,
             proc2mem_addr,
             proc2mem_data,

             // Outputs
             mem2proc_response,
             mem2proc_data,
             mem2proc_tag
           );
	always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clk = ~clk;
  end


  task show_io_mem;
	  begin
		if(
    $display("==OUTPUTS====================================================");
   	$display("Response\tData\tTag");
		$display("%d\t0x%h\t%d", mem2proc_response, mem2proc_data, mem2proc_tag );
    $display("=============================================================\n");
	  end
	endtask


	task show_io;
	  begin
		
    $display("==OUTPUTS====================================================");
   	$display("RDY1\tRDY2\tROB1\tROB2\tVAL1\tVAL2\tMISS\tBA");
		$display("%b\t%b\t%0d\t%0d\t%b\t%b\t%b\t%0d", !full, !full_almost, rob_idx_out1, rob_idx_out2, dout1_valid, dout2_valid, branch_miss, ba_out);
    $display("=============================================================\n");

	  end
	endtask


	task show_contents;
	  begin
		$display("==============================================================");
    $display("ROB Contents");
		$display("==============================================================");

    $display("Counter : %d",rob0.iocount);
		$display("Full  / Almost : %0d,%0d",rob0.full, rob0.full_almost);
		$display("Empty / Almost : %0d,%0d\n",rob0.empty, rob0.empty_almost);
    $display("Head : %d",rob0.head);
		$display("Tail : %d\n",rob0.tail);
    
		$display("         |  RDY\tBTEX\tBAEX\tNPC\tPDEST\tBTPD\tBAPD");
		$display("==============================================================");
    $display("Entry  0 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[0], rob0.data_bt_ex[0], rob0.data_ba_ex[0], rob0.cb_npc.data[0], rob0.cb_pdest.data[0], rob0.cb_bt_pd.data[0], rob0.cb_ba_pd.data[0]);
    $display("Entry  1 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[1], rob0.data_bt_ex[1], rob0.data_ba_ex[1], rob0.cb_npc.data[1], rob0.cb_pdest.data[1], rob0.cb_bt_pd.data[1], rob0.cb_ba_pd.data[1]);
    $display("Entry  2 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[2], rob0.data_bt_ex[2], rob0.data_ba_ex[2], rob0.cb_npc.data[2], rob0.cb_pdest.data[2], rob0.cb_bt_pd.data[2], rob0.cb_ba_pd.data[2]);
    $display("Entry  3 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[3], rob0.data_bt_ex[3], rob0.data_ba_ex[3], rob0.cb_npc.data[3], rob0.cb_pdest.data[3], rob0.cb_bt_pd.data[3], rob0.cb_ba_pd.data[3]);
    $display("Entry  4 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[4], rob0.data_bt_ex[4], rob0.data_ba_ex[4], rob0.cb_npc.data[4], rob0.cb_pdest.data[4], rob0.cb_bt_pd.data[4], rob0.cb_ba_pd.data[4]);
    $display("Entry  5 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[5], rob0.data_bt_ex[5], rob0.data_ba_ex[5], rob0.cb_npc.data[5], rob0.cb_pdest.data[5], rob0.cb_bt_pd.data[5], rob0.cb_ba_pd.data[5]);
    $display("Entry  6 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[6], rob0.data_bt_ex[6], rob0.data_ba_ex[6], rob0.cb_npc.data[6], rob0.cb_pdest.data[6], rob0.cb_bt_pd.data[6], rob0.cb_ba_pd.data[6]);
    $display("Entry  7 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[7], rob0.data_bt_ex[7], rob0.data_ba_ex[7], rob0.cb_npc.data[7], rob0.cb_pdest.data[7], rob0.cb_bt_pd.data[7], rob0.cb_ba_pd.data[7]);
/*  $display("Entry  8 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[8], rob0.data_bt_ex[8], rob0.data_ba_ex[8], rob0.cb_npc.data[8], rob0.cb_pdest.data[8], rob0.cb_bt_pd.data[8], rob0.cb_ba_pd.data[8]);
    $display("Entry  9 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[9], rob0.data_bt_ex[9], rob0.data_ba_ex[9], rob0.cb_npc.data[9], rob0.cb_pdest.data[9], rob0.cb_bt_pd.data[9], rob0.cb_ba_pd.data[9]);
    $display("Entry 10 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[10], rob0.data_bt_ex[10], rob0.data_ba_ex[10], rob0.cb_npc.data[10], rob0.cb_pdest.data[10], rob0.cb_bt_pd.data[10], rob0.cb_ba_pd.data[10]);
    $display("Entry 11 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[11], rob0.data_bt_ex[11], rob0.data_ba_ex[11], rob0.cb_npc.data[11], rob0.cb_pdest.data[11], rob0.cb_bt_pd.data[11], rob0.cb_ba_pd.data[11]);
    $display("Entry 12 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[12], rob0.data_bt_ex[12], rob0.data_ba_ex[12], rob0.cb_npc.data[12], rob0.cb_pdest.data[12], rob0.cb_bt_pd.data[12], rob0.cb_ba_pd.data[12]);
    $display("Entry 13 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[13], rob0.data_bt_ex[13], rob0.data_ba_ex[13], rob0.cb_npc.data[13], rob0.cb_pdest.data[13], rob0.cb_bt_pd.data[13], rob0.cb_ba_pd.data[13]);
    $display("Entry 14 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[14], rob0.data_bt_ex[14], rob0.data_ba_ex[14], rob0.cb_npc.data[14], rob0.cb_pdest.data[14], rob0.cb_bt_pd.data[14], rob0.cb_ba_pd.data[14]);
    $display("Entry 15 |  %b\t%b\t%0d\t%0d\t%0d\t%b\t%0d",rob0.data_rdy[15], rob0.data_bt_ex[15], rob0.data_ba_ex[15], rob0.cb_npc.data[15], rob0.cb_pdest.data[15], rob0.cb_bt_pd.data[15], rob0.cb_ba_pd.data[15]);
*/
		$display("==============================================================\n");
	  end
	endtask

	task reset_all;
	  begin
			count = 0;
			NPC = 0;
			reset = 0; din1_req = 0; din2_req = 0; dup1_req = 0; dup2_req = 0;
	    ir_in1 = 0; ir_in2 = 0;
	    npc_in1 = 0; npc_in2 = 0;
	    pdest_in1 = 0; pdest_in2 = 0;
	    bt_pd_in1 = 0; bt_pd_in2 = 0;
	    ba_pd_in1 = 0; ba_pd_in2 = 0;
	    bt_ex_in1 = 0; bt_ex_in2 = 0;
	    ba_ex_in1 = 0; ba_ex_in2 = 0;
	    rob_idx_in1 = 0; rob_idx_in2 = 0;
  	end
  endtask



  // Task to allocate an instruction 
  task new_inst;
	input [1:0] num_inst;
  input [`PRF_IDX-1:0] dest_idx1, dest_idx2;
	input bt_pd1, bt_pd2, isbranch1, isbranch2;
	input [63:0] ba_pd1, ba_pd2; 
  begin

    if (num_inst >= 1) begin
			din1_req = 1;
			din2_req = 0;
			
			NPC = NPC + 1;
			npc_in1 = NPC;  // arbitrary
			ir_in1 = NPC/2; // arbitrary
			pdest_in1 = dest_idx1;
			bt_pd_in1 = bt_pd1;
			ba_pd_in1 = ba_pd1; 
			isbranch_in1 = isbranch1;
			$display("Allocating Inst @%4.0fns: PRF=%0d, ISBR=%b, BT:%b, BA:%0d",	$time, dest_idx1, isbranch1, bt_pd1, ba_pd1);

			if (num_inst == 2) begin
				din2_req = 1;
				
				NPC = NPC + 1;
				npc_in2 = NPC;  // arbitrary
				ir_in2 = NPC/2; // arbitrary
				pdest_in2 = dest_idx2;
				bt_pd_in2 = bt_pd2;
				ba_pd_in2 = ba_pd2; 
				isbranch_in2 = isbranch2;
				$display("Allocating Inst @%4.0fns: PRF=%0d, ISBR=%b, BT:%b, BA:%0d",	$time, dest_idx2, isbranch2, bt_pd2, ba_pd2);
			end

		end else begin
			din1_req = 0;
			din2_req = 0;
		end
		
  end
  endtask

  // Task to update an instruction 
  task up_inst;
	input [1:0] num_inst;
	input [`ROB_IDX-1:0] rob1, rob2;
	input bt_ex1, bt_ex2;
	input [63:0] ba_ex1, ba_ex2; 
  begin

		rob_idx_in1 = rob1;
		rob_idx_in2 = rob2;

    if (num_inst >= 1) begin
			dup1_req = 1;
			dup2_req = 0;
			
			bt_ex_in1 = bt_ex1;
			ba_ex_in1 = ba_ex1;
			$display("Updating ROB #%0d @%4.0fns: BT=%b, BA=%0d",	rob1, $time, bt_ex1, ba_ex1);

			if (num_inst == 2) begin
				dup2_req = 1;
				
				bt_ex_in1 = bt_ex1;
				ba_ex_in1 = ba_ex1;
				$display("Updating ROB #%0d @%4.0fns: BT=%b, BA=%0d",	rob2, $time, bt_ex2, ba_ex2);
			end

		end else begin
			dup1_req = 0;
			dup2_req = 0;
		end
		
  end
  endtask

	initial
	  begin
    clk = 1'b0;
    // Reset ROB
    reset = 1'b1;@(negedge clk); reset = 1'b0; 

    // Initialize input signals
    reset_all();
  
    @(negedge clk);
		
		// #############################
		// USAGE:
		// new_inst(num_inst, dest_idx1, dest_idx2, bt_pd1, bt_pd2, isbranch1, isbranch2, ba_pd1, ba_pd2) 
		// up_inst(num_inst, rob1, rob2, bt_ex1, bt_ex2, ba_ex1, ba_ex2);
		// #############################

    $display("=============================================================");
    $display("@@@ Test case #1: Insert & Remove one at a time");
    $display("=============================================================\n");
    
    $display("============[        INSERT       ]==========================\n");
		// insert one at a time
		new_inst(2,2,3,0,0,0,0,0,0);
    @(negedge clk);show_contents();show_io();
		new_inst(2,2,3,1,0,0,0,0,0);
    @(negedge clk);show_contents();show_io();
		new_inst(1,5,3,0,0,0,0,0,0);
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
    @(negedge clk);show_contents();show_io();
		new_inst(0,5,3,0,0,0,0,0,0);
    @(negedge clk);show_contents();show_io();

    $display("============[        REMOVE       ]==========================\n");
		up_inst(2,0,1,0,0,0,0);
    @(negedge clk);show_contents();show_io();
		up_inst(1,4,0,0,0,0,0);
    @(negedge clk);show_contents();show_io();
		up_inst(0,4,0,0,0,0,0);


		// Test case #2: Pull items
    $display("=============================================================");
    $display("@@@ Test case #2: Insert and remove two at a time");
    $display("=============================================================\n");



		// Test case #3: Insert & pull items at the same time 
    $display("=============================================================");
    $display("@@@ Test case #3: Branch Misprediction");
    $display("=============================================================\n");
    // address mispredict

		// direction mispredict



    $display("All Testcase Passed!\n"); 
    $finish; 

		end
endmodule