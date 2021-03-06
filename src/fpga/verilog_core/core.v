`timescale 1ns / 1ps

`define VGA_HSIZE 640
`define VGA_VSIZE 480

`define HSIZE 256
`define VSIZE 256

`define VGA_PIXELS (VGA_VSIZE * VGA_HSIZE)
`define PIXELS (VSIZE * HSIZE)


module core(

		CLK,
		I_RESET,
		
		O_LED,
		I_SW,

		O_VBUS_ADDR,
		O_VBUS_WE,
		O_VBUS_DATA_TOVRAM,
		I_VBUS_DATA_FROMVRAM,
		
		I_VGA_VSYNC,

		I_ICE_BUS_CMD,
		O_ICE_BUS_RESP,
		O_ICE_BUS_TOICE,
		I_ICE_BUS_FROMICE
);

	`define s1_draw 0
	`define s1_movh 1
	`define s1_movl 2
	`define s1_beq 3
	`define s1_bgt 4
	`define s1_ba 5
	`define s1_ext_s2 6
	`define s1_ext_s3 7

	`define s2_mov 0
	`define s2_add 1
	`define s2_sub 2
	`define s2_neg 3

	`define s2_and 4
	`define s2_or 5
	`define s2_xor 6
	`define s2_not 7

	`define s2_shl 8
	`define s2_shr 9
	`define s2_sar 10
	`define s2_read16 11

	`define s2_write16 12
	`define s2_addi 13
	`define s2_subi 14
	`define s2_undefined 15

	`define s3_jr 0
	`define s3_wait 1
		

	`define state_fetch 0
	`define state_fetch_addr 1
	`define state_fetch_data 2
	`define state_execute 3
	`define state_memaccess 4
	`define state_memaccess_data 5
	`define state_vram_write 6
	`define state_vwait_in 7
	`define state_vwait_out 8

	input 	CLK, I_RESET;
	input 	I_VGA_VSYNC;
	
	input wire [7:0] I_ICE_BUS_CMD;
	input wire [15:0] I_ICE_BUS_FROMICE;
	
	output reg [7:0] O_ICE_BUS_RESP;
	output reg [15:0] O_ICE_BUS_TOICE;
	
	input [3:0] I_SW;

	output [3:0] O_LED;

	output reg O_VBUS_WE;
	output reg [15:0] O_VBUS_ADDR;
	input [2:0] I_VBUS_DATA_FROMVRAM;
	output reg [2:0] O_VBUS_DATA_TOVRAM;
	
	reg [12:0] ram_address;
	reg [15:0] ram_in;
	wire [15:0] ram_out;
	reg  ram_we;
	
	assign O_LED = I_SW;
	
	mem ram (
		.clka(CLK), // input clka
		.wea(ram_we), // input [0 : 0] wea
		.addra(ram_address), // input [12 : 0] addra
		.dina(ram_in), // input [15 : 0] dina
		.douta(ram_out) // output [15 : 0] douta
	);
	
	reg [15:0] regs[15:0];
	reg [15:0] pc;
	
	reg [3:0] state;
	
	reg [15:0] opcode;
	
	wire op_is_not_jump = opcode[15];
	
	wire [2:0] op_s1 = opcode[14:12];
	wire [3:0] op_s2 = opcode[11:8];
	wire [7:0] op_s3 = opcode[11:4];
	wire [14:0] op_imm15 = opcode[14:0];
	wire [7:0] op_imm8 = opcode[7:0];
	wire [3:0] op_imm4 = opcode[3:0];
	wire [15:0] op_imm4_s16 = { {12{op_imm4[3]}}, op_imm4[3:0] };
	
	wire [3:0] op_r3 = opcode[3:0];
	wire [3:0] op_r2 = opcode[7:4];
	wire [3:0] op_r1 = opcode[11:8];
	
	always@ (posedge CLK)
	begin
		if (I_RESET == 1)
		begin
			//if reset, then clear the state
			regs[0]=0;
			regs[1]=0;
			regs[2]=0;
			regs[3]=0;
			
			regs[4]=0;
			regs[5]=0;
			regs[6]=0;
			regs[7]=0;
			
			regs[8]=0;
			regs[9]=0;
			regs[10]=0;
			regs[11]=0;
			
			regs[12]=0;
			regs[13]=0;
			regs[14]=0;
			regs[15]=0;
			
			state=`state_fetch;
			pc=0;
			ram_address=0;
			ram_we=0;
			
			O_VBUS_WE = 0;
			O_VBUS_ADDR = 0;
			O_VBUS_DATA_TOVRAM = 0;
			//vram_in = 0;

			//LED = 4;
		end
		else
		begin
			//Do something
			
			case(state)
				`state_fetch:
				begin
				//if (ice_command)
				//.....
				
					ram_address = pc;
					// advance the state
					//if (!halt)
					state=`state_fetch_addr;
				end
				
				`state_fetch_addr:
				begin
					// advance the state
					state=`state_fetch_data;
				end
				
				`state_fetch_data:
				begin
					state=`state_execute;
					opcode = ram_out;
					pc = pc +1;
				end

				`state_execute:
				begin
					// advance the state
					state = `state_fetch;
					
					if (op_is_not_jump == 0)
					begin
						pc = op_imm15;
					end
					else
					begin
						case(op_s1)
							`s1_draw:
							begin
								state=`state_vram_write;
								O_VBUS_ADDR = regs[op_r2]* `HSIZE + regs[op_r1];
								O_VBUS_DATA_TOVRAM = regs[op_r3];
								O_VBUS_WE = 1;
							end
							`s1_movh: regs[op_r1][15:8] = op_imm8;
							`s1_movl: regs[op_r1] = op_imm8;
							`s1_beq: 
							if (regs[op_r1] == regs[op_r2]) begin
								pc = pc + op_imm4_s16 - 1;
							end
							`s1_bgt: 
							if ($signed(regs[op_r1]) > $signed(regs[op_r2])) begin
								pc = pc + op_imm4_s16 - 1;
							end
							`s1_ba: 
							if (regs[op_r1] > regs[op_r2]) begin
								pc = pc + op_imm4_s16 - 1;
							end
							`s1_ext_s2:
							begin
								case (op_s2)
									`s2_mov: regs[op_r2] = regs[op_r3];
									`s2_add: regs[op_r2] = regs[op_r2] + regs[op_r3];
									`s2_sub: regs[op_r2] = regs[op_r2] - regs[op_r3];
									
									`s2_and: regs[op_r2] = regs[op_r2] & regs[op_r3];
									`s2_or:  regs[op_r2] = regs[op_r2] | regs[op_r3];
									`s2_xor: regs[op_r2] = regs[op_r2] ^ regs[op_r3];
									
									`s2_neg: regs[op_r2] = -regs[op_r3];
									`s2_not: regs[op_r2] = ~regs[op_r3];

									`s2_shl: regs[op_r2] = regs[op_r2] << op_imm4;
									`s2_shr: regs[op_r2] = regs[op_r2] >> op_imm4;
									`s2_sar: regs[op_r2] = regs[op_r2] >>> op_imm4;
									`s2_read16:
									begin
										state = `state_memaccess;
										ram_address = regs[op_r3];
									end

									`s2_write16:
									begin
										state = `state_memaccess;
										ram_address = regs[op_r3];
										ram_in = regs[op_r2];
										ram_we = 1;
										//regs[op_r2] = ram[];
									end
									`s2_addi: regs[op_r2] = regs[op_r2] + op_imm4;
									`s2_subi: regs[op_r2] = regs[op_r2] - op_imm4;
									
									`s2_undefined: pc = pc +2;
								endcase
							end
							`s1_ext_s3: 
							case(op_s3)
							`s3_jr: pc = regs[op_r3];
							`s3_wait: state = `state_vwait_in;
							endcase
						endcase
					end
				end
				
				`state_vwait_in:
				begin
					if (I_VGA_VSYNC == 1)
						state = `state_vwait_out;
				end
				
				`state_vwait_out:
				begin
					if (I_VGA_VSYNC == 0)
						state = `state_fetch;
				end
				
				`state_memaccess:
				begin
					state = `state_memaccess_data;
				end
				
				`state_memaccess_data:
				begin
					state = `state_fetch;
					if (ram_we == 0)
						regs[op_r2] = ram_out;
					ram_we = 0;
				end
				
				`state_vram_write:
				begin
					state = `state_fetch;
					O_VBUS_WE=0;
				end
			endcase
		end
	end
	
endmodule

