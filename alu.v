// DESIGN SPECIFIC
`define ALU_BUS_WITH 		16
`define ALU_AMM_ADDR_WITH 	8
`define ALU_AMM_DATA_WITH	8   

/**

== Input packets ==

Header beat
+-----------------+--------------+---------------+------------------+
| reserved[15:12] | opcode[11:8] | reserved[7:6] | nof_operands[5:0]|
+-----------------+--------------+---------------+------------------+

Payload beat
+-----------------+----------+----------------------+
| reserved[15:10] | mod[9:8] | operands/address[7:0]|
+-----------------+----------+----------------------+

== Output packets ==

Header beat

+----------------+----------+-------------+
| reserved[15:5] | error[4] | opcode[3:0] |
+----------------+----------+-------------+

Payload beat

+-----------------+--------------+
| reserved[15:12] | result[11:0] |
+-----------------+--------------+

*/

//declarare macrocomenzi stari
`define reset                 'h00            // reset state
`define read_header				'h10
`define read_payload				'h20
`define generate_header			'h30
`define generate_payload		'h40
`define read_memory				'h50


//declarare macrocomenzi operatii
`define ADD						0
`define AND                1
`define OR                 2
`define XOR                3
`define NOT                4
`define INC                5
`define DEC                6
`define NEG                7
`define SHR                8
`define SHL						9

module alu(
	 // Output interface
    output[`ALU_BUS_WITH - 1:0] data_out,
	 output 							  valid_out,
	 output 							  cmd_out,

	 //Input interface
	 input [`ALU_BUS_WITH - 1:0] data_in,
	 input 							  valid_in,
	 input 							  cmd_in,
	 
	 // AMM interface
	 output 									 amm_read,
	 output[`ALU_AMM_ADDR_WITH - 1:0] amm_address,
	 input [`ALU_AMM_DATA_WITH - 1:0] amm_readdata,
	 input 									 amm_waitrequest,
	 input[1:0] 							 amm_response,
	 
	 
	 //clock and reset interface
	 input clk,
	 input rst_n
    );
	
	// TODO: Implement Not-so-simple ALU
	//declaratie variabile
	parameter state_width = 16;
	reg[state_width-1 : 0] state = `reset, next_state;
	reg[5:0] nof_operands; 				//pana la 63 (2^6-1) de operanzi
	reg[3:0] opcode; 						//codul operatiei
	reg[1:0] mod;							//modul de adresare;
	reg[7:0] operand[0:63];				//vectori operanzi pt adresare indirecta
	reg[7:0] operand_dir;				//operand pentru adresare directa
	reg error;								//eroare iesire
	reg[11:0] result;						//rezultatul operatiei
	
	reg[5:0] last_index;
	reg[5:0] current_index;
	reg[10:0] counter_next, counter;
	reg[5:0] nof;
	reg[7:0] shiftop1, shiftop2;
	
	reg[`ALU_BUS_WITH - 1:0]  		reg_data_out;
	reg 							  		reg_valid_out;
	reg 							  		reg_cmd_out;
	reg 									reg_amm_read;
	reg[`ALU_AMM_ADDR_WITH - 1:0] reg_amm_address;
		

	initial begin
		counter <= 0;
		counter_next <= 0;
	end

	//partea secventiala
	always @(posedge clk) begin
	
		state <= next_state;
		counter <= counter_next;
		
		if(!rst_n) begin
			state <= `reset;	
		end
	end
	
	//partea combinationala
	always @(*) begin
		reg_data_out = 0;
		reg_valid_out = 0;
		reg_cmd_out = 0;
		reg_amm_read = 0;
		reg_amm_address = 0;
		
		//analizare stari
		case(state)
			`reset: begin
						//counter = 0;
						counter_next = 0;
						current_index = 0;
						last_index = 0;
						error = 0;
						nof = 0;
						nof_operands = 0;
						opcode = 0;
						shiftop1 = 0;
						shiftop2 = 0;
						result = 0;
						
						next_state = `read_header;
			end
			
			`read_header: begin
						if(cmd_in == 1 && valid_in == 1) begin
							opcode = data_in[11:8];
							nof_operands = data_in[5:0];
							next_state = `read_payload;
							nof = nof_operands;
							
							if(nof_operands == 0) begin
								error = 1;
								next_state = `generate_header;
							end
							
							if(nof_operands != 1 && (opcode == 4 || opcode == 5 || opcode == 6 || opcode == 7)) begin
								error = 1;
								next_state = `generate_header;
							end
							
							if(opcode == 1)
								result = 12'b111111111111;
						end	
						else next_state = `read_header;

			end
			
			`read_payload: begin
								if(valid_in == 1 && cmd_in == 0 && counter_next == counter) begin
								counter_next = counter_next + 1;
								mod = data_in[9:8];
								operand_dir = data_in[7:0];

								if(mod == 2'b00) begin
									case(opcode)
										`ADD: begin
											result = result + operand_dir;
										end
										
										`AND: begin
											result = result & operand_dir;
										end
										
										`OR: begin
											result = result | operand_dir;
										end
										
										`XOR: begin
											result = result ^ operand_dir;
										end
										
										`NOT: begin
											result = ~operand_dir;
										end
										
										`INC: begin
											result = operand_dir + 1;
										end
										
										`DEC: begin
											result = operand_dir - 1;
										end
										
										`NEG: begin
											result = ~operand_dir + 1;
										end
										
										`SHR: begin
											if(nof_operands == 2) begin
												result = !result? operand_dir: result >> operand_dir;
												if(last_index == 1)
													shiftop2 = operand_dir;
											end
											if(nof_operands != 2) error = 1;
										end
										
										`SHL: begin
											if(nof_operands == 2) begin
												result = !result? operand_dir: result << operand_dir;
												if(last_index == 1)
													shiftop2 = operand_dir;
											end
											if(nof_operands != 2) error = 1;
										end
									endcase
							end
							
							if (mod == 2'b01) begin
								operand[last_index] = operand_dir;
								last_index = last_index + 1;
							end

							nof = nof - 1;	
							next_state = `read_payload;
							
							if(nof == 0) begin
								next_state = `generate_header;
								if(last_index != 0) begin
									next_state = `read_memory;
								end
							end
						end
					
			end
			
			`read_memory: begin
				reg_amm_address = operand[current_index];
				if(reg_amm_address < 'h00 || (reg_amm_address > 'h0F && reg_amm_address < 'h30) || (reg_amm_address > 'h7F && reg_amm_address < 'hA0) || reg_amm_address > 'hFF)
				begin
					error = 1;
					next_state = `generate_header;
				end
				reg_amm_read = 1;

				if(amm_waitrequest == 0) begin
					if(amm_response != 2'b00) begin
						error = 1;
						next_state = `generate_header;
					end
					if(amm_response == 2'b00) begin
							current_index = current_index + 1;
							operand_dir = amm_readdata;
							case(opcode)
								`ADD: begin
									result = result + operand_dir;
								end
								
								`AND: begin
									result = result & operand_dir;
								end
								
								`OR: begin
									result = result | operand_dir;
								end
								
								`XOR: begin
									result = result ^ operand_dir;
								end
								
								`NOT: begin
									result = ~operand_dir;
								end
								
								`INC: begin
									result = operand_dir + 1;
								end
								
								`DEC: begin
									result = operand_dir - 1;
								end
								
								`NEG: begin
									result = ~operand_dir + 1;
								end
								
								`SHR: begin
									if(nof_operands == 2)
										result = !result? operand_dir: result >> operand_dir;
										if(last_index == 1) begin
											shiftop1 = operand_dir;
											result = shiftop1 >> shiftop2;
										end
									if(nof_operands != 2) error = 1;
								end
										
								`SHL: begin
									if(nof_operands == 2)
										result = !result? operand_dir: result << operand_dir;
										if(last_index == 1) begin
											shiftop1 = operand_dir;
											result = shiftop1 << shiftop2;
										end
									if(nof_operands != 2) error = 1;
								end
						endcase				

						if(current_index == last_index)
							next_state = `generate_header;
						if(current_index != last_index)
							next_state = `read_memory;
					end
				end
				else next_state = `read_memory;
			end
			
			`generate_header: begin
						reg_data_out[15:5] = 0;
						reg_data_out[4] = error;
						reg_data_out[3:0] = opcode;
						reg_valid_out = 1;
						reg_cmd_out = 1;
						
						next_state = `generate_payload;
			end
			
			`generate_payload: begin
						reg_data_out[15:12] = 0;
						if(opcode == 4 || opcode == 9 || opcode == 7)
							result  = {4'b0, result[7:0]};
						if(error == 1)
							result = 16'hBAD;
						reg_data_out[11:0] = result;
						reg_valid_out = 1;
						reg_cmd_out = 0;
						
						next_state = `reset;
			end
		endcase
	end
		
	assign data_out = reg_data_out;
	assign valid_out = reg_valid_out;
	assign cmd_out = reg_cmd_out;
	assign amm_address = reg_amm_address;
	assign amm_read = reg_amm_read;
endmodule

