`include "global_params.v"

module reservation_station (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,

    // from ALU
    input wire                           alu_ready,
    input wire [          `XLEN - 1 : 0] alu_res,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] alu_id,     // the rob id of the instruction being calculated

    // from Decoder
    input wire                          dec_ready,
    input wire [`INST_OP_WIDTH - 1 : 0] dec_op,
    input wire                          dec_jump_pred,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rd,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rs1,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rs2,
    input wire [         `XLEN - 1 : 0] dec_imm,

    // from Memory Controller
    input wire                           mem_data_ready,
    input wire [          `XLEN - 1 : 0] mem_data,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] mem_id,          // the rob id of the load instruction

    // from RF
    input wire [            `XLEN - 1 : 0] rf_val1,  // value of register dec_rs1
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,  // dependency of register dec_rs1
    input wire [            `XLEN - 1 : 0] rf_val2,  // value of register dec_rs2
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2,  // dependency of register dec_rs2

    // from ROB
    input wire                           rob_Q1_ready,
    input wire [          `XLEN - 1 : 0] rob_Q1_val,
    input wire                           rob_Q2_ready,
    input wire [          `XLEN - 1 : 0] rob_Q2_val,
    input wire [  `ALU_OP_WIDTH - 1 : 0] rob_rs_remove_op,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,

    // output
    output wire [`ROB_SIZE_WIDTH - 1 : 0] rs_remove_id,  // to ROB
    output reg                            rs_full,
    output reg                            rs_ready,      // to ALU
    output reg  [  `ALU_OP_WIDTH - 1 : 0] rs_op,         // to ALU
    output reg  [          `XLEN - 1 : 0] rs_val1,       // to ALU
    output reg  [          `XLEN - 1 : 0] rs_val2,       // to ALU
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] rs_id          // to ALU; the rob id of the instruction being calculated
);
    reg                              busy                  [`RS_SIZE - 1 : 0];
    reg  [`DEPENDENCY_WIDTH - 1 : 0] Q1                    [`RS_SIZE - 1 : 0];
    reg  [            `XLEN - 1 : 0] V1                    [`RS_SIZE - 1 : 0];
    reg  [`DEPENDENCY_WIDTH - 1 : 0] Q2                    [`RS_SIZE - 1 : 0];
    reg  [            `XLEN - 1 : 0] V2                    [`RS_SIZE - 1 : 0];
    reg  [  `ROB_SIZE_WIDTH - 1 : 0] id                    [`RS_SIZE - 1 : 0];  // the rob id

    wire                             tmp_inst_should_enter;
    wire                             tmp_two_op;
    reg                              tmp_insert_break_flag;
    reg  [   `RS_SIZE_WIDTH - 1 : 0] tmp_insert_id;
    reg                              tmp_remove_break_flag;
    reg  [   `RS_SIZE_WIDTH - 1 : 0] tmp_remove_id;
    reg                              tmp_should_remove;
    reg  [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q1;
    reg  [            `XLEN - 1 : 0] tmp_new_V1;
    reg  [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q2;
    reg  [            `XLEN - 1 : 0] tmp_new_V2;
    reg  [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q1;
    reg  [            `XLEN - 1 : 0] tmp_new_updated_V1;
    reg  [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q2;
    reg  [            `XLEN - 1 : 0] tmp_new_updated_V2;

    assign rs_remove_id          = tmp_remove_id;
    assign tmp_inst_should_enter = (dec_op != `LUI && dec_op != `AUIPC && dec_op != `JAL && dec_op != `LB && dec_op != `LH && dec_op != `LW && dec_op != `LBU && dec_op != `LHU && dec_op != `SB && dec_op != `SH && dec_op != `SW);
    assign tmp_two_op            = (dec_op != `JALR && dec_op != `ADDI && dec_op != `SLTI && dec_op != `SLTIU && dec_op != `XORI && dec_op != `ORI && dec_op != `ANDI && dec_op != `SLLI && dec_op != `SRLI && dec_op != `SRAI);

    initial begin
        rs_full  = 1'b0;
        rs_ready = 1'b0;
        rs_op    = `ALU_OP_WIDTH'b0;
        rs_val1  = `XLEN'b0;
        rs_val2  = `XLEN'b0;
        rs_id    = `ROB_SIZE_WIDTH'b0;
        for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
            busy[i] = 1'b0;
            Q1[i]   = -`DEPENDENCY_WIDTH'b1;
            V1[i]   = `XLEN'b0;
            Q2[i]   = -`DEPENDENCY_WIDTH'b1;
            V2[i]   = `XLEN'b0;
            id[i]   = `ROB_SIZE_WIDTH'b0;
        end
        tmp_insert_break_flag = 1'b0;
        tmp_insert_id         = `RS_SIZE_WIDTH'b0;
        tmp_remove_break_flag = 1'b0;
        tmp_remove_id         = `RS_SIZE_WIDTH'b0;
        tmp_should_remove     = 1'b0;
        tmp_new_Q1            = `DEPENDENCY_WIDTH'b0;
        tmp_new_V1            = `XLEN'b0;
        tmp_new_Q2            = `DEPENDENCY_WIDTH'b0;
        tmp_new_V2            = `XLEN'b0;
        tmp_new_updated_Q1    = `DEPENDENCY_WIDTH'b0;
        tmp_new_updated_V1    = `XLEN'b0;
        tmp_new_updated_Q2    = `DEPENDENCY_WIDTH'b0;
        tmp_new_updated_V2    = `XLEN'b0;
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
        rs_full = (tmp_insert_id == `RS_SIZE_WIDTH'b0 && tmp_insert_break_flag == 1'b0);  // all busy[i] is 1'b1
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

    always @(*) begin
        if (|rf_dep1) begin  // rf_dep1 == -1
            tmp_new_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_V1 = rf_val1;
        end else begin
            if (rob_Q1_ready) begin
                tmp_new_Q1 = -`DEPENDENCY_WIDTH'b1;
                tmp_new_V1 = rob_Q1_val;
            end else begin
                tmp_new_Q1 = rf_dep1;
                tmp_new_V1 = `XLEN'b0;
            end
        end
        if (tmp_new_Q1 == mem_id) begin  // zero extension: mem_id
            tmp_new_updated_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V1 = mem_data;
        end else if (tmp_new_Q1 == alu_id) begin  // zero extension: alu_id
            tmp_new_updated_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V1 = alu_res;
        end else begin
            tmp_new_updated_Q1 = tmp_new_Q1;
            tmp_new_updated_V1 = tmp_new_V1;
        end
    end

    always @(*) begin
        if (tmp_two_op) begin
            if (|rf_dep2) begin  // rf_dep2 == -1
                tmp_new_Q2 = -`DEPENDENCY_WIDTH'b1;
                tmp_new_V2 = rf_val2;
            end else begin
                if (rob_Q2_ready) begin
                    tmp_new_Q2 = -`DEPENDENCY_WIDTH'b1;
                    tmp_new_V2 = rob_Q2_val;
                end else begin
                    tmp_new_Q2 = rf_dep2;
                    tmp_new_V2 = `XLEN'b0;
                end
            end
        end else begin
            tmp_new_Q2 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_V2 = dec_imm;
        end
        if (tmp_new_Q2 == mem_id) begin  // zero extension: mem_id
            tmp_new_updated_Q2 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V2 = mem_data;
        end else if (tmp_new_Q2 == alu_id) begin  // zero extension: alu_id
            tmp_new_updated_Q2 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V2 = alu_res;
        end else begin
            tmp_new_updated_Q2 = tmp_new_Q2;
            tmp_new_updated_V2 = tmp_new_V2;
        end
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst) begin
                rs_ready <= 1'b0;
                rs_op    <= `ALU_OP_WIDTH'b0;
                rs_val1  <= `XLEN'b0;
                rs_val2  <= `XLEN'b0;
                rs_id    <= `ROB_SIZE_WIDTH'b0;
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    busy[i] <= 1'b0;
                    Q1[i]   <= -`DEPENDENCY_WIDTH'b1;
                    V1[i]   <= `XLEN'b0;
                    Q2[i]   <= -`DEPENDENCY_WIDTH'b1;
                    V2[i]   <= `XLEN'b0;
                    id[i]   <= `ROB_SIZE_WIDTH'b0;
                end
            end else if (flush) begin
                rs_ready <= 1'b0;
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    busy[i] <= 1'b0;
                end
            end else begin
                if (!stall && dec_ready && tmp_inst_should_enter) begin
                    busy[tmp_insert_id] <= 1'b1;
                    id[tmp_insert_id]   <= rob_tail_id;
                    Q1[tmp_insert_id]   <= tmp_new_updated_Q1;
                    V1[tmp_insert_id]   <= tmp_new_updated_V1;
                    Q2[tmp_insert_id]   <= tmp_new_updated_Q2;
                    V2[tmp_insert_id]   <= tmp_new_updated_V2;
                end
                if (mem_data_ready) begin
                    for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                        if (busy[i]) begin
                            if (Q1[i] == mem_id) begin  // zero extension: mem_id
                                Q1[i] <= -`DEPENDENCY_WIDTH'b1;
                                V1[i] <= mem_data;
                            end
                            if (Q2[i] == mem_id) begin  // zero extension: mem_id
                                Q2[i] <= -`DEPENDENCY_WIDTH'b1;
                                V2[i] <= mem_data;
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
                    case (rob_rs_remove_op)
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
    end
endmodule
