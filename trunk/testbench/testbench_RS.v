/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench_RS.v                                      //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps


module testbench;

  integer idx, limbo_inst;  //TEST VARS

  // Registers and wires used in the testbench
  reg  clk, reset;

  reg  rs_en;   // I'm being allocated
  reg  [`PRF_IDX-1:0] prega_idx, pregb_idx, pdest_idx;
  reg  prega_valid, pregb_valid;
  reg  [4:0] ALUop;
  reg  rd_mem, wr_mem;
  reg  [31:0] rs_IR; 
  reg  cond_branch, uncond_branch;
  reg  [63:0] npc;
  reg  mult_free, ALU_free, mem_free;
  reg  [`SCALAR-1:0] cdb_valid;
  reg  [`SCALAR*`PRF_IDX-1:0] cdb_tag;
  reg  [`ROB_IDX-1:0] rob_idx;
  reg  [(`SCALAR-1)*`RS_SZ-1:0] entry_flush;

  wire  rs_free, ALU_rdy, mem_rdy, mult_rdy;
  wire  [`PRF_IDX-1:0] pdest_idx_out, prega_idx_out, pregb_idx_out;
  wire  [4:0] ALUop_out;
  wire  rd_mem_out, wr_mem_out;
  wire  [31:0] rs_IR_out;
  wire  [63:0] npc_out;
  wire  [`ROB_IDX-1:0] rob_idx_out;
  wire  [`RS_IDX-1:0]  rs_idx_out;
  

  // Instatiate the Reservation Station
  RS rs_0 (clk, reset,
                //INPUTS
                rs_en, prega_idx, pregb_idx, pdest_idx, prega_valid, pregb_valid, //RAT
                ALUop, rd_mem, wr_mem, rs_IR,  npc, cond_branch, uncond_branch, //Issue Stage
                mult_free, ALU_free, mem_free, cdb_valid, cdb_tag, entry_flush, //Pipeline communication
                rob_idx,  //ROB

                //OUTPUT
                rs_free,  ALU_rdy, mem_rdy, mult_rdy, //Hazard d etect
                pdest_idx_out, prega_idx_out, pregb_idx_out, ALUop_out, rd_mem_out,   //FU
                wr_mem_out, rs_IR_out, npc_out, rob_idx_out,                          //FU
                rs_idx_out                                                            //ROB
          );

  // Generate System Clock
  always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clk = ~clk;
  end

  always @(posedge clk)
  begin
    if(rs_en)
    begin
      if (limbo_inst < `RS_SZ && !rs_free)
      begin // Empty condition!
        $display("@@@ Fail! Time: %4.0f RS is supposed to be have an empty entry, but doesn't! @@@", $time);
        $finish;
      end
      limbo_inst = limbo_inst + (rs_free ? 1 : 0);
      if(limbo_inst > `RS_SZ)
      begin   // Full condition!
        $display("@@@ Fail! Time: %4.0f RS is supposed to be full, but isn't! @@@", $time);
        $finish;
      end
    end
    if((ALU_rdy & ALU_free) || (mem_rdy & mem_free) || (mult_rdy & mult_free))
    begin
      if(limbo_inst <= 0)
      begin
        $display("@@@ Fail! Time: %4.0f RS entry is said to be ready, but no RS entry is allocated! @@@", $time);
        $display("@@@ dest: %h opA: %h opB: %h ALUop: %h rd_mem: %h wr_mem: %h IR: %h NPC: %h ROB: %h",
                  pdest_idx_out, prega_idx_out, pregb_idx_out, ALUop_out, rd_mem_out, wr_mem_out, rs_IR_out,
                  npc_out, rob_idx_out);
        $finish;
      end
      else
        limbo_inst = limbo_inst - 1;
    end
  end

  // Task to insert an instruction 
  task insert_inst;
  input [`PRF_IDX-1:0] rega_idx, regb_idx, dest_idx;
  input rega_valid, regb_valid, rdmem_in, wrmem_in;
  input [4:0] ALUop_in;
  begin
    npc = npc + 2;
    rob_idx = rob_idx + 1;
    rs_en = 1'b1;

    prega_idx = rega_idx;
    pregb_idx = regb_idx;
    pdest_idx = dest_idx;
    prega_valid = rega_valid;
    pregb_valid = regb_valid;
    ALUop = ALUop_in;
    rd_mem = rdmem_in;
    wr_mem = wrmem_in;
    rs_IR = rob_idx; // whatever
    cond_branch = 1'b0;
    uncond_branch = 1'b0;
		
	$display("Inserting Inst@%4.0fns: [%0d(%d), %0d(%d)] => %0d (ROB#: %d, npc: %0d), ALUop: 0x%h, rdmem: %d, wrmem: %d",
				$time, rega_idx, rega_valid, regb_idx, regb_valid, dest_idx, rob_idx, npc, ALUop_in, rdmem_in, wrmem_in);

  end
  endtask

  task insert_ALUinst;
    input [`PRF_IDX-1:0] rega_idx, regb_idx, dest_idx;
    input rega_valid, regb_valid, mult;
    insert_inst(rega_idx, regb_idx, dest_idx, rega_valid, regb_valid, 0, 0, mult ? `ALU_MULQ : `ALU_ADDQ);
  endtask

  task insert_MEMinst;
    input [`PRF_IDX-1:0] rega_idx, regb_idx, dest_idx;
    input rega_valid, regb_valid, rdmem_in, wrmem_in;
    insert_inst(rega_idx, regb_idx, dest_idx, rega_valid, regb_valid, rdmem_in, wrmem_in, 0);
  endtask
	// Task to set CDB Tag/Valid
	task set_CDB;
		input [`PRF_IDX-1:0] tag;
		input valid;
        input scalar;
		begin
            if(scalar) begin
			cdb_tag[2*`PRF_IDX-1:`PRF_IDX] = tag;
			cdb_valid[1] = valid;
            end
            else begin
			cdb_tag[`PRF_IDX-1:0] = tag;
			cdb_valid[0] = valid;
            end
			$display("Setting CDB%0b@%4.0fns: Register Tag = %0d		Valid = %d", scalar, $time, tag, valid);
            $display("CDB is: 0x%h %b", cdb_tag, cdb_valid);
		end
	endtask

	task CDB_fail;
		begin
			$display("@@@ Fail! CDB is broadcasting, but the valid bit has not been updated @ %4.0d", $time);
			$finish;
		end
	endtask

  // Task to display RS content of an Entry
  task show_entry_content;
  begin
  `ifdef SYNTH
    $display("");
  `else
    $display("============================================================================================ ");
    $display("Entry| ALU/RD/WR | Dest	| A Tag / Vld | B Tag	/ Vld | Free	| Ready	|	IR    | ROB#  ");
    $display("============================================================================================ ");
    $display(" 15  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[15].entry.ALUop_out, rs_0.entries[15].entry.rd_mem_out, rs_0.entries[15].entry.wr_mem_out, rs_0.entries[15].entry.pdest_idx_out, rs_0.entries[15].entry.prega_idx_out, rs_0.entries[15].entry.prega_rdy, rs_0.entries[15].entry.pregb_idx_out, rs_0.entries[15].entry.pregb_rdy, rs_0.entries[15].entry.entry_free, rs_0.entries[15].entry.ALU_rdy | rs_0.entries[15].entry.mem_rdy | rs_0.entries[15].entry.mult_rdy, rs_0.entries[15].entry.rs_IR_out, rs_0.entries[15].entry.rob_idx_out);
    $display(" 14  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[14].entry.ALUop_out, rs_0.entries[14].entry.rd_mem_out, rs_0.entries[14].entry.wr_mem_out, rs_0.entries[14].entry.pdest_idx_out, rs_0.entries[14].entry.prega_idx_out, rs_0.entries[14].entry.prega_rdy, rs_0.entries[14].entry.pregb_idx_out, rs_0.entries[14].entry.pregb_rdy, rs_0.entries[14].entry.entry_free, rs_0.entries[14].entry.ALU_rdy | rs_0.entries[14].entry.mem_rdy | rs_0.entries[14].entry.mult_rdy, rs_0.entries[14].entry.rs_IR_out, rs_0.entries[14].entry.rob_idx_out);
    $display(" 13  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[13].entry.ALUop_out, rs_0.entries[13].entry.rd_mem_out, rs_0.entries[13].entry.wr_mem_out, rs_0.entries[13].entry.pdest_idx_out, rs_0.entries[13].entry.prega_idx_out, rs_0.entries[13].entry.prega_rdy, rs_0.entries[13].entry.pregb_idx_out, rs_0.entries[13].entry.pregb_rdy, rs_0.entries[13].entry.entry_free, rs_0.entries[13].entry.ALU_rdy | rs_0.entries[13].entry.mem_rdy | rs_0.entries[13].entry.mult_rdy, rs_0.entries[13].entry.rs_IR_out, rs_0.entries[13].entry.rob_idx_out);
    $display(" 12  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[12].entry.ALUop_out, rs_0.entries[12].entry.rd_mem_out, rs_0.entries[12].entry.wr_mem_out, rs_0.entries[12].entry.pdest_idx_out, rs_0.entries[12].entry.prega_idx_out, rs_0.entries[12].entry.prega_rdy, rs_0.entries[12].entry.pregb_idx_out, rs_0.entries[12].entry.pregb_rdy, rs_0.entries[12].entry.entry_free, rs_0.entries[12].entry.ALU_rdy | rs_0.entries[12].entry.mem_rdy | rs_0.entries[12].entry.mult_rdy, rs_0.entries[12].entry.rs_IR_out, rs_0.entries[12].entry.rob_idx_out);
    $display(" 11  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[11].entry.ALUop_out, rs_0.entries[11].entry.rd_mem_out, rs_0.entries[11].entry.wr_mem_out, rs_0.entries[11].entry.pdest_idx_out, rs_0.entries[11].entry.prega_idx_out, rs_0.entries[11].entry.prega_rdy, rs_0.entries[11].entry.pregb_idx_out, rs_0.entries[11].entry.pregb_rdy, rs_0.entries[11].entry.entry_free, rs_0.entries[11].entry.ALU_rdy | rs_0.entries[11].entry.mem_rdy | rs_0.entries[11].entry.mult_rdy, rs_0.entries[11].entry.rs_IR_out, rs_0.entries[11].entry.rob_idx_out);
    $display(" 10  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[10].entry.ALUop_out, rs_0.entries[10].entry.rd_mem_out, rs_0.entries[10].entry.wr_mem_out, rs_0.entries[10].entry.pdest_idx_out, rs_0.entries[10].entry.prega_idx_out, rs_0.entries[10].entry.prega_rdy, rs_0.entries[10].entry.pregb_idx_out, rs_0.entries[10].entry.pregb_rdy, rs_0.entries[10].entry.entry_free, rs_0.entries[10].entry.ALU_rdy | rs_0.entries[10].entry.mem_rdy | rs_0.entries[10].entry.mult_rdy, rs_0.entries[10].entry.rs_IR_out, rs_0.entries[10].entry.rob_idx_out);
    $display("  9  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[9].entry.ALUop_out, rs_0.entries[9].entry.rd_mem_out, rs_0.entries[9].entry.wr_mem_out, rs_0.entries[9].entry.pdest_idx_out, rs_0.entries[9].entry.prega_idx_out, rs_0.entries[9].entry.prega_rdy, rs_0.entries[9].entry.pregb_idx_out, rs_0.entries[9].entry.pregb_rdy, rs_0.entries[9].entry.entry_free, rs_0.entries[9].entry.ALU_rdy | rs_0.entries[9].entry.mem_rdy | rs_0.entries[9].entry.mult_rdy, rs_0.entries[9].entry.rs_IR_out, rs_0.entries[9].entry.rob_idx_out);
    $display("  8  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[8].entry.ALUop_out, rs_0.entries[8].entry.rd_mem_out, rs_0.entries[8].entry.wr_mem_out, rs_0.entries[8].entry.pdest_idx_out, rs_0.entries[8].entry.prega_idx_out, rs_0.entries[8].entry.prega_rdy, rs_0.entries[8].entry.pregb_idx_out, rs_0.entries[8].entry.pregb_rdy, rs_0.entries[8].entry.entry_free, rs_0.entries[8].entry.ALU_rdy | rs_0.entries[8].entry.mem_rdy | rs_0.entries[8].entry.mult_rdy, rs_0.entries[8].entry.rs_IR_out, rs_0.entries[8].entry.rob_idx_out);
    $display("  7  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[7].entry.ALUop_out, rs_0.entries[7].entry.rd_mem_out, rs_0.entries[7].entry.wr_mem_out, rs_0.entries[7].entry.pdest_idx_out, rs_0.entries[7].entry.prega_idx_out, rs_0.entries[7].entry.prega_rdy, rs_0.entries[7].entry.pregb_idx_out, rs_0.entries[7].entry.pregb_rdy, rs_0.entries[7].entry.entry_free, rs_0.entries[7].entry.ALU_rdy | rs_0.entries[7].entry.mem_rdy | rs_0.entries[7].entry.mult_rdy, rs_0.entries[7].entry.rs_IR_out, rs_0.entries[7].entry.rob_idx_out);
    $display("  6  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[6].entry.ALUop_out, rs_0.entries[6].entry.rd_mem_out, rs_0.entries[6].entry.wr_mem_out, rs_0.entries[6].entry.pdest_idx_out, rs_0.entries[6].entry.prega_idx_out, rs_0.entries[6].entry.prega_rdy, rs_0.entries[6].entry.pregb_idx_out, rs_0.entries[6].entry.pregb_rdy, rs_0.entries[6].entry.entry_free, rs_0.entries[6].entry.ALU_rdy | rs_0.entries[6].entry.mem_rdy | rs_0.entries[6].entry.mult_rdy, rs_0.entries[6].entry.rs_IR_out, rs_0.entries[6].entry.rob_idx_out);
    $display("  5  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[5].entry.ALUop_out, rs_0.entries[5].entry.rd_mem_out, rs_0.entries[5].entry.wr_mem_out, rs_0.entries[5].entry.pdest_idx_out, rs_0.entries[5].entry.prega_idx_out, rs_0.entries[5].entry.prega_rdy, rs_0.entries[5].entry.pregb_idx_out, rs_0.entries[5].entry.pregb_rdy, rs_0.entries[5].entry.entry_free, rs_0.entries[5].entry.ALU_rdy | rs_0.entries[5].entry.mem_rdy | rs_0.entries[5].entry.mult_rdy, rs_0.entries[5].entry.rs_IR_out, rs_0.entries[5].entry.rob_idx_out);
    $display("  4  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[4].entry.ALUop_out, rs_0.entries[4].entry.rd_mem_out, rs_0.entries[4].entry.wr_mem_out, rs_0.entries[4].entry.pdest_idx_out, rs_0.entries[4].entry.prega_idx_out, rs_0.entries[4].entry.prega_rdy, rs_0.entries[4].entry.pregb_idx_out, rs_0.entries[4].entry.pregb_rdy, rs_0.entries[4].entry.entry_free, rs_0.entries[4].entry.ALU_rdy | rs_0.entries[4].entry.mem_rdy | rs_0.entries[4].entry.mult_rdy, rs_0.entries[4].entry.rs_IR_out, rs_0.entries[4].entry.rob_idx_out);
    $display("  3  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[3].entry.ALUop_out, rs_0.entries[3].entry.rd_mem_out, rs_0.entries[3].entry.wr_mem_out, rs_0.entries[3].entry.pdest_idx_out, rs_0.entries[3].entry.prega_idx_out, rs_0.entries[3].entry.prega_rdy, rs_0.entries[3].entry.pregb_idx_out, rs_0.entries[3].entry.pregb_rdy, rs_0.entries[3].entry.entry_free, rs_0.entries[3].entry.ALU_rdy | rs_0.entries[3].entry.mem_rdy | rs_0.entries[3].entry.mult_rdy, rs_0.entries[3].entry.rs_IR_out, rs_0.entries[3].entry.rob_idx_out);
    $display("  2  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[2].entry.ALUop_out, rs_0.entries[2].entry.rd_mem_out, rs_0.entries[2].entry.wr_mem_out, rs_0.entries[2].entry.pdest_idx_out, rs_0.entries[2].entry.prega_idx_out, rs_0.entries[2].entry.prega_rdy, rs_0.entries[2].entry.pregb_idx_out, rs_0.entries[2].entry.pregb_rdy, rs_0.entries[2].entry.entry_free, rs_0.entries[2].entry.ALU_rdy | rs_0.entries[2].entry.mem_rdy | rs_0.entries[2].entry.mult_rdy, rs_0.entries[2].entry.rs_IR_out, rs_0.entries[2].entry.rob_idx_out);
    $display("  1  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[1].entry.ALUop_out, rs_0.entries[1].entry.rd_mem_out, rs_0.entries[1].entry.wr_mem_out, rs_0.entries[1].entry.pdest_idx_out, rs_0.entries[1].entry.prega_idx_out, rs_0.entries[1].entry.prega_rdy, rs_0.entries[1].entry.pregb_idx_out, rs_0.entries[1].entry.pregb_rdy, rs_0.entries[1].entry.entry_free, rs_0.entries[1].entry.ALU_rdy | rs_0.entries[1].entry.mem_rdy | rs_0.entries[1].entry.mult_rdy, rs_0.entries[1].entry.rs_IR_out, rs_0.entries[1].entry.rob_idx_out);
    $display("  0  |  0x%h/%d/%d |  %0d	|  %0d	/ %b   |  %0d	/ %b   | 0x%h	| 0x%h	| 0x%h  | %0d   ", rs_0.entries[0].entry.ALUop_out, rs_0.entries[0].entry.rd_mem_out, rs_0.entries[0].entry.wr_mem_out, rs_0.entries[0].entry.pdest_idx_out, rs_0.entries[0].entry.prega_idx_out, rs_0.entries[0].entry.prega_rdy, rs_0.entries[0].entry.pregb_idx_out, rs_0.entries[0].entry.pregb_rdy, rs_0.entries[0].entry.entry_free, rs_0.entries[0].entry.ALU_rdy | rs_0.entries[0].entry.mem_rdy | rs_0.entries[0].entry.mult_rdy, rs_0.entries[0].entry.rs_IR_out, rs_0.entries[0].entry.rob_idx_out);
    $display("============================================================================================\n\n "); 
  `endif
  end
  endtask

  task reset_all;
  begin
	  rs_en = 0;
	  prega_idx = 0;
	  pregb_idx = 0;
	  pdest_idx = 0;
	  prega_valid = 0;
	  pregb_valid = 0;
	  ALUop = 0;
	  rd_mem = 0;
	  wr_mem = 0;
	  rs_IR = 0;
	  cond_branch = 0;
	  uncond_branch = 0;
	  npc = 0;
	  mult_free = 0;
	  ALU_free = 0;
	  mem_free = 0;
	  cdb_valid = 0;
	  cdb_tag = 0;
	  rob_idx = 0;
    limbo_inst = 0;
  end
  endtask
  
  // Testbench
  initial
  begin
//    $monitor("time : %4.0f,  npc: %0d, rs_free: %h, rs_rdy: %h, ALU_free: %h, mem_free: %h, mult_free: %h, cdb_valid: %h, cdb_tag: %h, entry_idx: %h\n", $time, npc, rs_free, rs_rdy, ALU_free, mem_free, mult_free, cdb_valid, cdb_tag, rs_0.entry_idx);
    reset = 1'b1;
    clk = 1'b0;
    reset_all();
    @(negedge clk);
    reset = 1'b0;
    // Initialize input signals
    @(negedge clk);
	$display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case: Insert until full\n", $time);
    $display("=============================================================\n");

    for(idx=0;idx<`RS_SZ;idx=idx+1)
    begin
      @(negedge clk);
      insert_ALUinst(idx,idx+1,idx+2,0,0,0);
    end
    @(negedge clk);
    rs_en = 1'b0;   //Check the next cycle to see if full, but don't add another instruction
    @(posedge clk);
    if(rs_free)
    begin
      $display("@@@ Fail! ALU full test failed");
      $finish;
    end
    else
      $display("@@@ Success! ALU full test passed");

    $display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case: Validate cdb on each instruction and test for empty\n", $time);
    $display("=============================================================\n");
    @(negedge clk);
    ALU_free=1'b1;          //Free an ALU entry every clock cycle
    set_CDB(5'b0, 1'b1, 1'b0);    //Set the first register for the first instruction
    @(negedge clk);
    for(idx=0;idx<`RS_SZ; idx=idx+1)
    begin
      set_CDB(idx+1, 1'b1, 1'b0); //Send the first operand (next iteration will get the second operand)
      @(posedge clk);
      if(!ALU_rdy) begin
        $display("@@@ Fail! rs_rdy not asserted when instruction should be ready");
        $display("@@@ Limbo: %0d  rs_free: %h", limbo_inst, rs_free);
        $finish;
      end
      if(mem_rdy || mult_rdy) begin
        $display("@@@ Fail! Ready signals for mem/mult asserted but only ALU_rdy should be");
        $display("ALU_rdy: %b mem_rdy: %b mult_rdy: %b", ALU_rdy, mem_rdy, mult_rdy);
      end
      if(prega_idx_out != idx || pregb_idx_out != idx+1 || pdest_idx_out != idx+2 ||
         ALUop_out != 0 || rd_mem_out != 0 || wr_mem_out != 0 || rs_IR_out != idx+1 ||
         npc_out != 2*(idx+1) || rob_idx_out != idx+1)
       begin
         $display("@@@ Fail! Instruction output does not match expected values!");
         $display("@@@ dest: %h opA: %h opB: %h ALUop: %h rd_mem: %h wr_mem: %h IR: %h NPC: %h ROB: %h",
                  pdest_idx_out, prega_idx_out, pregb_idx_out, ALUop_out, rd_mem_out, wr_mem_out, rs_IR_out,
                  npc_out, rob_idx_out);
         $finish;
       end
      @(negedge clk);
    end
    @(posedge clk);
    if(!rs_free)
    begin
      $display("@@@ Fail! ALU empty test failed");
      $finish;
    end
    else
      $display("@@@ Success! ALU empty test passed");
    ALU_free=1'b0; //Disable ALUs
    set_CDB(0,0,0); //Disable CDB

    reset_all();
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    // Test case #1.1: Insert new instruction 
   
    $display("=============================================================\n");
    $display("@@@ Test case #1.1: Insert ALU instruction\n");
    $display("=============================================================\n");
    

    insert_ALUinst(1,2,3,1,1,0);
    @(negedge clk);show_entry_content();
    insert_ALUinst(2,3,4,1,0,0);
    @(negedge clk);show_entry_content();
    insert_ALUinst(3,4,5,0,0,0);
    @(negedge clk);show_entry_content();
    insert_ALUinst(4,5,6,0,0,0);
    ALU_free=1'b1; 
    set_CDB(3,1,0); 
    @(negedge clk);show_entry_content();
    insert_ALUinst(5,6,7,0,0,0);
    ALU_free=1'b1; 
    set_CDB(4,1,0); 
    @(negedge clk);show_entry_content();
    rs_en = 1'b0;  // disable RS No more Inst
    ALU_free=1'b1; 
    set_CDB(5,1,0); 
    @(negedge clk);show_entry_content();
    ALU_free=1'b1; 
    set_CDB(6,1,0); 
    @(negedge clk);show_entry_content();
    ALU_free=1'b1; 
    set_CDB(7,1,0);
    @(negedge clk); show_entry_content();
    $display("@@@ Success!  Test #1.1 Passed!");

    reset_all();
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    
    $display("=============================================================\n");
    $display("@@@ Test case #1.2: Insert MULT instruction\n");
    $display("=============================================================\n");
    
    insert_ALUinst(1,2,3,1,1,1);show_entry_content();
    @(negedge clk);
    insert_ALUinst(2,3,4,1,0,1);show_entry_content();
    @(negedge clk);
    insert_ALUinst(3,4,5,0,0,1);show_entry_content();
    @(negedge clk);
    insert_ALUinst(4,5,6,0,0,1);show_entry_content();
    mult_free=1'b1; 
    set_CDB(3,1,0); 
    @(negedge clk);show_entry_content();
    insert_ALUinst(5,6,7,0,0,1);
    mult_free=1'b1; 
    set_CDB(4,1,0); 
    @(negedge clk);show_entry_content();
    rs_en = 1'b0;  // disable RS No more Inst
    mult_free=1'b1; 
    set_CDB(5,1,0); 
    @(negedge clk);show_entry_content();
    mult_free=1'b1; 
    set_CDB(6,1,0); 
    @(negedge clk);show_entry_content();
    mult_free=1'b1; 
    set_CDB(7,1,0);
    @(negedge clk); show_entry_content();

    $display("@@@ Success!  Test #1.2 Passed!");

    reset_all();
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    // Test case #1.3: Insert new instruction 
    
    $display("=============================================================\n");
    $display("@@@ Test case #1.3: Insert MEM instruction\n");
    $display("=============================================================\n");
    
    insert_MEMinst(1,2,3,1,1,1,0);
    @(negedge clk);show_entry_content();
    insert_MEMinst(2,3,4,1,0,1,0);
    @(negedge clk);show_entry_content();
    insert_MEMinst(3,4,5,0,0,1,0);
    @(negedge clk);show_entry_content();
    insert_MEMinst(4,5,6,0,0,1,0);
    mem_free=1'b1; 
    set_CDB(3,1,0); 
    @(negedge clk);show_entry_content();
    insert_MEMinst(5,6,7,0,0,1,0);
    mem_free=1'b1; 
    set_CDB(4,1,0); 
    @(negedge clk);show_entry_content();
    rs_en = 1'b0;  // disable RS No more Inst
    mem_free=1'b1; 
    set_CDB(5,1,0); 
    @(negedge clk);show_entry_content();
    mem_free=1'b1; 
    set_CDB(6,1,0); 
    @(negedge clk);show_entry_content();
    mem_free=1'b1; 
    set_CDB(7,1,0);
    @(negedge clk);  show_entry_content();

    $display("@@@ Success!  Test #1.3 Passed!");

    // Reset RS
    reset = 1'b1;      // Assert Reset
    clk = 1'b0;
    @(negedge clk);
    reset = 1'b0;      // Deassert Reset
    rs_en = 1'b1;  // Enable RS
    // Initialize input signals
    reset_all();

  
    // Test case #x.x: CDB Test
	@(negedge clk); 
	$display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case: Basic Internal CDB Test\n", $time);
    $display("=============================================================\n");
  `ifdef SYNTH
    $display("Test not applicable in synth mode");
  `else
	reset_all(); @(negedge clk); show_entry_content();

    insert_ALUinst( 1, 2, 3,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 2, 3, 4,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 3, 4, 5,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 4, 5, 6,0,0,1); @(negedge clk); show_entry_content();
    insert_ALUinst( 5, 6, 7,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 6, 7, 8,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 7, 8, 9,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst( 8, 9,10,0,0,1); @(negedge clk); show_entry_content();
    insert_ALUinst( 9,10,11,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst(10,11,12,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst(11,12,13,0,0,0); @(negedge clk); show_entry_content();
    insert_ALUinst(12,13,14,0,0,1); @(negedge clk); show_entry_content();
    insert_inst(13,14,15,0,0,0,1,0); @(negedge clk); show_entry_content();
    insert_inst(14,15,16,0,0,0,0,1); @(negedge clk); show_entry_content();
    insert_inst(15,16,17,0,0,0,1,0); @(negedge clk); show_entry_content();
    insert_inst(16,17,18,0,0,0,0,1); @(negedge clk); show_entry_content();

    set_CDB(2, 1, 0); @(negedge clk); show_entry_content();
		if(rs_0.entries[15].entry.pregb_rdy==1'b0 | rs_0.entries[14].entry.prega_rdy==1'b0) CDB_fail();
    set_CDB(2, 0, 0); @(negedge clk); show_entry_content();
		if(rs_0.entries[15].entry.pregb_rdy==1'b0 | rs_0.entries[14].entry.prega_rdy==1'b0) CDB_fail();
    set_CDB(3, 1, 0); @(negedge clk); show_entry_content();
		if(rs_0.entries[14].entry.pregb_rdy==1'b0 | rs_0.entries[13].entry.prega_rdy==1'b0) CDB_fail();
    set_CDB(4, 1, 0); @(negedge clk); show_entry_content();
		if(rs_0.entries[13].entry.pregb_rdy==1'b0 | rs_0.entries[12].entry.prega_rdy==1'b0) CDB_fail();
    set_CDB(5, 1, 0); @(negedge clk); show_entry_content();
		if(rs_0.entries[12].entry.pregb_rdy==1'b0 | rs_0.entries[11].entry.prega_rdy==1'b0) CDB_fail();
   
	$display("@@@ Success! Basic CDB test passed");
		
	@(negedge clk);
    `endif

	$display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case #5.1: FU becomes free, but no inst ready\n", $time);
    $display("=============================================================\n");

		// reset rs
		reset_all();
		@(negedge clk);
		reset = 1'b1;
		ALU_free = 1'b0;
		mult_free = 1'b0;
		@(negedge clk);
		reset = 1'b0;
		@(negedge clk);

		// begin test
    for(idx=0;idx<`RS_SZ; idx=idx+1)
    begin
		insert_ALUinst(5,9,21,0,0,0); @(negedge clk);
	end
	rs_en = 1'b0;
	ALU_free = 1'b1;
	@(negedge clk);
	@(negedge clk);
	mult_free = 1'b1;
	@(negedge clk);
	@(negedge clk);
	show_entry_content();
    
    @(posedge clk);
	if(rs_free)
    begin
      $display("@@@ Fail! Test case #5.1 failed");
      $finish;
    end

    $display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case #5.2: FU is free, ready instr come in\n", $time);
    $display("=============================================================\n");

		// reset rs
		reset_all();
		@(negedge clk);
		reset = 1'b1;
		ALU_free = 1'b0;
		mult_free = 1'b0;
		@(negedge clk);
		reset = 1'b0;
		@(negedge clk);

		// begin test
		mult_free = 1'b1;
		@(negedge clk);
		insert_ALUinst(6,2,14,1,1,1);	@(negedge clk);
		mult_free = 1'b0;
		ALU_free = 1'b1;
		@(negedge clk);
		insert_ALUinst(1,3,9,1,1,0);	@(negedge clk);
    
		show_entry_content();

    @(posedge clk);
	if(!rs_free)
    begin
      $display("@@@ Fail! Test case #5.2 failed");
      $finish;
    end
		

    $display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case #5.3: more than one instr's ready, FU/MEM becomes free\n", $time);
    $display("=============================================================\n");
`ifndef SYNTH
    $display("Test not applicable in synth mode");
`else
		// reset rs
		reset_all();
		@(negedge clk);
		reset = 1'b1;
		@(negedge clk);
		reset = 1'b0;
		@(negedge clk);

		// begin test
		@(negedge clk);
		insert_ALUinst(6,2,3,1,1,1);		@(negedge clk); show_entry_content();
        insert_MEMinst(1,2,3,1,1,1,0);	    @(negedge clk); show_entry_content();
        insert_MEMinst(2,1,4,1,0,0,1);	    @(negedge clk); show_entry_content();
		insert_ALUinst(3,1,2,1,0,0);		@(negedge clk); show_entry_content();
		rs_en = 1'b0;

		ALU_free = 1'b1; $display("ex is free now");
		set_CDB(1,1,0); 
		@(negedge clk);show_entry_content();
		// first alu instruction should be out
		if (!rs_0.entries[12].entry.entry_free)
        begin
          $display("@@@ Fail! Test case #5.3 failed");
          $finish;
        end

		insert_ALUinst(4,8,4,1,1,1); 		@(negedge clk);show_entry_content();

		mem_free = 1'b1; $display("mem is free now");
		insert_ALUinst(2,6,1,1,1,1); 		@(negedge clk);show_entry_content();
		if (!rs_0.entries[14].entry.entry_free)
        begin
          $display("@@@ Fail! Test case #5.3 failed");
          $finish;
        end
		rs_en = 1'b0;
		mult_free = 1'b1;$display("mult is free now");

		@(negedge clk);show_entry_content();
		if (!rs_0.entries[15].entry.entry_free)
        begin
          $display("@@@ Fail! Test case #5.3 failed");
          $finish;
        end

		@(negedge clk);show_entry_content();
		@(negedge clk);show_entry_content();
		@(negedge clk);show_entry_content();

		show_entry_content();
        @(posedge clk);
		if(!rs_free)
        begin
          $display("@@@ Fail! Test case #5.3 failed");
          $finish;
        end

`endif
    $display("=============================================================\n");
    $display("@@@ Time: %4.0f  Test case #5.4: FU becomes free as new ready inst comes in\n", $time);
    $display("=============================================================\n");
		
		// reset rs
		reset_all();
		@(negedge clk);
		reset = 1'b1;
		@(negedge clk);
		reset = 1'b0;
		@(negedge clk);

		// begin test
		@(negedge clk);
		mult_free = 1'b1;
		insert_ALUinst(6,2,3,1,1,1);
		@(negedge clk);
		ALU_free = 1'b1;
		insert_ALUinst(3,1,2,1,0,0);
		@(negedge clk);

		show_entry_content();
    @(posedge clk);
	if(!rs_free)
    begin
      $display("@@@ Fail! Test case #5.4 failed");
      $finish;
    end

		// this should be a CDB test case
    $display("=============================================================\n");
    $display("@@@ Test case #5.5: As an inst comes in, FU becomes free, CDB makes it ready\n");
    $display("=============================================================\n");
		// reset rs
		reset_all();
		@(negedge clk);
		reset = 1'b1;
		@(negedge clk);
		reset = 1'b0;
		@(negedge clk);

		insert_ALUinst(6,2,3,0,1,1);
		set_CDB(6,1,0);
		mult_free = 1'b1;
        @(posedge clk); $display("rs_cdb_valid %b rs_cdb_tag %h next_prega_valid %b", rs_0.entries[15].entry.cdb_valid[0], rs_0.entries[15].entry.cdb_tag[`PRF_IDX-1:0], rs_0.entries[15].entry.next_prega_rdy);
        $display("prega_rdy %d, entry_en %d, prega_valid %d, prega_idx_out %d", rs_0.entries[15].entry.prega_rdy, rs_0.entries[15].entry.entry_en, rs_0.entries[15].entry.prega_valid, rs_0.entries[15].entry.prega_idx_out);
		@(negedge clk);show_entry_content();
        rs_en = 1'b0;
        set_CDB(0,0,0);
    @(posedge clk);
    if (ALUop_out != `ALU_MULQ || prega_idx_out != 6 || pregb_idx_out != 2 || pdest_idx_out != 3)
    begin
       $display("@@@ Fail! Instruction output does not match expected values!");
       $display("@@@ dest: %h opA: %h opB: %h ALUop: %h rd_mem: %h wr_mem: %h IR: %h NPC: %h ROB: %h",
                pdest_idx_out, prega_idx_out, pregb_idx_out, ALUop_out, rd_mem_out, wr_mem_out, rs_IR_out,
                npc_out, rob_idx_out);
       $finish;
    end
    else
      $display("@@@ Success! Test case pass!");

    $display("@@@ Success: All Testcases Passed!\n"); 
    $finish; 
  end


endmodule  // module testbench
