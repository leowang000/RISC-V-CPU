`include "global_params.v"

module reservation_station (
    // input
    input wire clk,
    input wire flush,
    input wire stall,

    // from ALU
    input wire                           alu_ready,
    input wire                           alu_res,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] alu_id,     // the rob id of the instruction being calculated

    // from Decoder
    input wire                            dec_ready,
    input wire [`INST_TYPE_WIDTH - 1 : 0] dec_inst_type,
    input wire                            dec_jump_pred,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rd,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rs1,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rs2,
    input wire [           `XLEN - 1 : 0] dec_imm,

    // from Memory
    input wire                           mem_ready,
    input wire [          `XLEN - 1 : 0] mem_res,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] mem_id,     // the rob id of the load instruction

    // from RF
    input wire [            `XLEN - 1 : 0] rf_val1,  // value of register dec_rs1
    input wire [            `XLEN - 1 : 0] rf_val2,  // value of register dec_rs2
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,  // dependency of register dec_rs1
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2,  // dependency of register dec_rs2

    // from ROB


    // output
    output wire                           rs_full,
    output reg                            rs_ready,  // to ALU
    output reg  [  `ALU_OP_WIDTH - 1 : 0] rs_op,     // to ALU
    output reg  [          `XLEN - 1 : 0] rs_val1,   // to ALU
    output reg  [          `XLEN - 1 : 0] rs_val2,   // to ALU
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] rs_id      // to ALU, the rob id of the instruction being calculated
);
    reg                              busy                  [`RS_SIZE - 1 : 0];
    reg  [`DEPENDENCY_WIDTH - 1 : 0] Q1                    [`RS_SIZE - 1 : 0];
    reg  [`DEPENDENCY_WIDTH - 1 : 0] Q2                    [`RS_SIZE - 1 : 0];
    reg  [            `XLEN - 1 : 0] V1                    [`RS_SIZE - 1 : 0];
    reg  [            `XLEN - 1 : 0] V2                    [`RS_SIZE - 1 : 0];
    reg  [  `ROB_SIZE_WIDTH - 1 : 0] id                    [`RS_SIZE - 1 : 0];  // the rob id

    wire                             tmp_inst_should_enter;
    wire                             tmp_two_op;
    reg                              tmp_insert_break_flag;
    reg  [   `RS_SIZE_WIDTH - 1 : 0] tmp_insert_id;
    reg                              tmp_remove_break_flag;
    reg  [   `RS_SIZE_WIDTH - 1 : 0] tmp_remove_id;
    reg                              tmp_should_remove;

    assign rs_full = &busy;
    assign tmp_inst_should_enter = (dec_inst_type != `LUI && dec_inst_type != `AUIPC && dec_inst_type != `JAL && dec_inst_type != `LB &&
        dec_inst_type != `LH && dec_inst_type != `LW && dec_inst_type != `LBU && dec_inst_type != `LHU && dec_inst_type != `SB &&
        dec_inst_type != `SH && dec_inst_type != `SW && dec_inst_type != `HALT);
    assign tmp_two_op = (dec_inst_type != `JALR && dec_inst_type != `ADDI && dec_inst_type != `SLTI && dec_inst_type != `SLTIU &&
        dec_inst_type != `XORI && dec_inst_type != `ORI && dec_inst_type != `ANDI && dec_inst_type != `SLLI && dec_inst_type != `SRLI && 
        dec_inst_type != `SRAI);

    initial begin
        rs_ready = 1'b0;
        rs_op    = `ALU_OP_WIDTH'b0;
        rs_val1  = `XLEN'b0;
        rs_val2  = `XLEN'b0;
        rs_id    = `ROB_SIZE_WIDTH'b0;
        for (integer i = 0; i < RS_SIZE; i = i + 1) begin
            busy[i] = 1'b0;
            Q1[i]   = -`DEPENDENCY_WIDTH'b1;
            Q2[i]   = -`DEPENDENCY_WIDTH'b1;
            V1[i]   = `XLEN'b0;
            V2[i]   = `XLEN'b0;
            id[i]   = `ROB_SIZE_WIDTH'b0;
        end
        tmp_inst_should_enter = 1'b0;
        tmp_two_op            = 1'b0;
        tmp_insert_break_flag = 1'b0;
        tmp_insert_id         = `RS_SIZE_WIDTH'b0;
        tmp_remove_break_flag = 1'b0;
        tmp_remove_id         = `RS_SIZE_WIDTH'b0;
        tmp_should_remove     = 1'b0;
    end

    always @(*) begin
        tmp_insert_id         = `RS_SIZE_WIDTH'b0;
        tmp_insert_break_flag = 1'b0;
        for (integer i = 0; i < `REG_CNT && !tmp_insert_break_flag; i = i + 1) begin
            if (!busy[i]) begin
                tmp_insert_id         = i;
                tmp_insert_break_flag = 1'b1;
            end
        end
    end

    always @(*) begin
        tmp_remove_id         = `RS_SIZE_WIDTH'b0;
        tmp_should_remove     = 1'b0;
        tmp_remove_break_flag = 1'b0;
        for (integer i = 0; i < `REG_CNT && !tmp_remove_break_flag; i = i + 1) begin
            if (busy[i] && |Q1[i] && |Q2[i]) begin  // busy[i] && Q1[i] == -1 && Q2[i] == -1
                tmp_remove_id         = i;
                tmp_should_remove     = 1'b1;
                tmp_remove_break_flag = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (flush) begin
            rs_ready <= 1'b0;
            for (integer i = 0; i < RS_SIZE; i = i + 1) begin
                busy[i] <= 1'b0;
            end
        end else begin
            if (!stall && dec_ready && tmp_inst_should_enter) begin
                // TODO: InsertInst
            end
            if (mem_ready) begin
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i]) begin
                        if (Q1[i] == mem_id) begin  // zero extension: mem_id
                            Q1[i] <= -`DEPENDENCY_WIDTH'b1;
                            V1[i] <= mem_res;
                        end
                        if (Q2[i] == mem_id) begin  // zero extension: mem_id
                            Q2[i] <= -`DEPENDENCY_WIDTH'b1;
                            V2[i] <= mem_res;
                        end
                    end
                end
            end
            if (alu_ready) begin
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i]) begin
                        if (Q1[i] == alu_id) begin  // zero extension: alu_id
                            Q1[i] <= -`DEPENDENCY_WIDTH'b1;
                            V1[i] <= alu_res;
                        end
                        if (Q2[i] == alu_id) begin  // zero extension: alu_id
                            Q2[i] <= -`DEPENDENCY_WIDTH'b1;
                            V2[i] <= alu_res;
                        end
                    end
                end
            end
            if (tmp_should_remove) begin
                rs_ready <= 1'b1;
                rs_val1  <= V1[tmp_remove_id];
                rs_val2  <= V2[tmp_remove_id];
                rs_id    <= id[tmp_remove_id];
                case (0)  // TODO: should be rb_queue[rs_.GetCur()[rs_id].id_].inst_type_
                    `JALR, `ADD, `ADDI: rs_op <= `ALU_ADD;
                    `SUB: rs_op <= `ALU_SUB;
                    `AND, `ANDI: rs_op <= `ALU_AND;
                    `OR, `ORI: rs_op <= `ALU_OR;
                    `XOR, `XORI: rs_op <= `ALU_XOR;
                    `SLL, `SLLI: rs_op <= `ALU_SHL;
                    `SRL, `SRLI: rs_op <= `ALU_SHR;
                    `SRA, `SRAI: rs_op <= `ALU_SHRA;
                    `BEQ: rs_op <= `ALU_EQ;
                    `BNE: rs_op <= `ALU_NEQ;
                    `SLT, `SLTI, `BLT: rs_op <= `ALU_LT;
                    `SLTU, `SLTIU, `BLTU: rs_op <= `ALU_LTU;
                    `BGE: rs_op <= `ALU_GE;
                    `BGEU: rs_op <= `ALU_GEU;
                    default: rs_op <= `ALU_OP_WIDTH'b0;
                endcase
                busy[tmp_remove_id] <= 1'b0;
            end else begin
                rs_ready <= 1'b0;
            end
        end
    end
endmodule
