`ifndef GLOBAL_PARAMS_V
`define GLOBAL_PARAMS_V

// always ensure `~ == 2 ** `~_WIDTH

`define XLEN 32
`define REG_CNT 32
`define REG_CNT_WIDTH 5

// ALU
`define ALU_OP_WIDTH 4
`define ALU_ADD `ALU_OP_WIDTH'd0
`define ALU_SUB `ALU_OP_WIDTH'd1
`define ALU_AND `ALU_OP_WIDTH'd2
`define ALU_OR `ALU_OP_WIDTH'd3
`define ALU_XOR `ALU_OP_WIDTH'd4
`define ALU_SHL `ALU_OP_WIDTH'd5
`define ALU_SHR `ALU_OP_WIDTH'd6
`define ALU_SHRA `ALU_OP_WIDTH'd7
`define ALU_EQ `ALU_OP_WIDTH'd8
`define ALU_NEQ `ALU_OP_WIDTH'd9
`define ALU_LT `ALU_OP_WIDTH'd10
`define ALU_LTU `ALU_OP_WIDTH'd11
`define ALU_GE `ALU_OP_WIDTH'd12
`define ALU_GEU `ALU_OP_WIDTH'd13

// BP
`define BP_SIZE 256
`define BP_SIZE_WIDTH 8

// Icache
`define ICACHE_SET_CNT 256  // direct-mapped cache; 2 bytes in each line, 0.5K in total
`define TAG_LEN 8
`define ICACHE_TAG_RANGE 16:9
`define ICACHE_INDEX_RANGE 8:1

// LSB
`define LSB_SIZE 16  // capacity = 15
`define LSB_SIZE_WIDTH 4

// ROB
`define ROB_SIZE 32  // capacity = 31
`define ROB_SIZE_WIDTH 5
`define DEPENDENCY_WIDTH 6  // -1 for no dependency; always ensure `DEPENDENCY_WIDTH == `ROB_SIZE_WIDTH + 1

// RS
`define RS_SIZE 16  // capacity = 16
`define RS_SIZE_WIDTH 4

// Decoder
`define INST_OP_WIDTH 6
`define LUI `INST_OP_WIDTH'd0
`define AUIPC `INST_OP_WIDTH'd1
`define JAL `INST_OP_WIDTH'd2
`define JALR `INST_OP_WIDTH'd3
`define BEQ `INST_OP_WIDTH'd4
`define BNE `INST_OP_WIDTH'd5
`define BLT `INST_OP_WIDTH'd6
`define BGE `INST_OP_WIDTH'd7
`define BLTU `INST_OP_WIDTH'd8
`define BGEU `INST_OP_WIDTH'd9
`define LB `INST_OP_WIDTH'd10
`define LH `INST_OP_WIDTH'd11
`define LW `INST_OP_WIDTH'd12
`define LBU `INST_OP_WIDTH'd13
`define LHU `INST_OP_WIDTH'd14
`define SB `INST_OP_WIDTH'd15
`define SH `INST_OP_WIDTH'd16
`define SW `INST_OP_WIDTH'd17
`define ADDI `INST_OP_WIDTH'd18
`define SLTI `INST_OP_WIDTH'd19
`define SLTIU `INST_OP_WIDTH'd20
`define XORI `INST_OP_WIDTH'd21
`define ORI `INST_OP_WIDTH'd22
`define ANDI `INST_OP_WIDTH'd23
`define SLLI `INST_OP_WIDTH'd24
`define SRLI `INST_OP_WIDTH'd25
`define SRAI `INST_OP_WIDTH'd26
`define ADD `INST_OP_WIDTH'd27
`define SUB `INST_OP_WIDTH'd28
`define SLL `INST_OP_WIDTH'd29
`define SLT `INST_OP_WIDTH'd30
`define SLTU `INST_OP_WIDTH'd31
`define XOR `INST_OP_WIDTH'd32
`define SRL `INST_OP_WIDTH'd33
`define SRA `INST_OP_WIDTH'd34
`define OR `INST_OP_WIDTH'd35
`define AND `INST_OP_WIDTH'd36

`endif
