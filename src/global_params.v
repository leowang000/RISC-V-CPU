`ifndef GLOBAL_PARAMS_V
`define GLOBAL_PARAMS_V

`define XLEN 32
`define REG_CNT 32
`define REG_CNT_WIDTH 5

// ALU
`define ALU_ADD 4'd0 // ALU op type
`define ALU_SUB 4'd1
`define ALU_AND 4'd2
`define ALU_OR 4'd3
`define ALU_XOR 4'd4
`define ALU_SHL 4'd5
`define ALU_SHR 4'd6
`define ALU_SHRA 4'd7
`define ALU_EQ 4'd8
`define ALU_NEQ 4'd9
`define ALU_LT 4'd10
`define ALU_LTU 4'd11
`define ALU_GE 4'd12
`define ALU_GEU 4'd13
`define ALU_OP_WIDTH 4

// ROB
`define ROB_SIZE 32
`define ROB_SIZE_WIDTH 5

// Decoder
`define LUI 6'd0
`define AUIPC 6'd1
`define JAL 6'd2
`define JALR 6'd3
`define BEQ 6'd4
`define BNE 6'd5
`define BLT 6'd6
`define BGE 6'd7
`define BLTU 6'd8
`define BGEU 6'd9
`define LB 6'd10
`define LH 6'd11
`define LW 6'd12
`define LBU 6'd13
`define LHU 6'd14
`define SB 6'd15
`define SH 6'd16
`define SW 6'd17
`define ADDI 6'd18
`define SLTI 6'd19
`define SLTIU 6'd20
`define XORI 6'd21
`define ORI 6'd22
`define ANDI 6'd23
`define SLLI 6'd24
`define SRLI 6'd25
`define SRAI 6'd26
`define ADD 6'd27
`define SUB 6'd28
`define SLL 6'd29
`define SLT 6'd30
`define SLTU 6'd31
`define XOR 6'd32
`define SRL 6'd33
`define SRA 6'd34
`define OR 6'd35
`define AND 6'd36
`define HALT 6'd37
`define INST_TYPE_WIDTH 6

`endif
