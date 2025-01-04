`include "global_params.v"

module load_store_buffer (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,
    input wire io_buffer_full,

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
    input wire [         `XLEN - 1 : 0] dec_inst_addr,

    // from Memory Controller
    input wire                           mem_busy,
    input wire                           mem_data_ready,
    input wire [          `XLEN - 1 : 0] mem_data,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] mem_id,

    // from RF
    input wire [            `XLEN - 1 : 0] rf_val1,  // value of register dec_rs1
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,  // dependency of register dec_rs1
    input wire [            `XLEN - 1 : 0] rf_val2,  // value of register dec_rs2
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2,  // dependency of register dec_rs2

    // from ROB
    input wire                           rob_mem_enable,
    input wire                           rob_Q1_ready,
    input wire [          `XLEN - 1 : 0] rob_Q1_val,
    input wire                           rob_Q2_ready,
    input wire [          `XLEN - 1 : 0] rob_Q2_val,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_head_id,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,

    // output
    output wire                             lsb_full,
    output wire                             lsb_empty,
    output wire [   `INST_OP_WIDTH - 1 : 0] lsb_front_op,    // to ROB
    output wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q1,    // to ROB
    output wire [            `XLEN - 1 : 0] lsb_front_V1,    // to ROB
    output wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q2,    // to ROB
    output wire [            `XLEN - 1 : 0] lsb_front_V2,    // to ROB
    output wire [  `ROB_SIZE_WIDTH - 1 : 0] lsb_front_id,    // to ROB
    output reg                              lsb_mem_enable,  // to Memory Controller
    output reg  [   `INST_OP_WIDTH - 1 : 0] lsb_mem_op,      // to Memory Controller
    output reg  [            `XLEN - 1 : 0] lsb_mem_addr,    // to Memory Controller
    output reg  [  `ROB_SIZE_WIDTH - 1 : 0] lsb_mem_id       // to Memory Controller
);
    integer                             i;

    reg                                 busy               [`LSB_SIZE - 1 : 0];
    reg     [   `INST_OP_WIDTH - 1 : 0] op                 [`LSB_SIZE - 1 : 0];
    reg     [`DEPENDENCY_WIDTH - 1 : 0] Q1                 [`LSB_SIZE - 1 : 0];
    reg     [            `XLEN - 1 : 0] V1                 [`LSB_SIZE - 1 : 0];
    reg     [`DEPENDENCY_WIDTH - 1 : 0] Q2                 [`LSB_SIZE - 1 : 0];
    reg     [            `XLEN - 1 : 0] V2                 [`LSB_SIZE - 1 : 0];
    reg     [  `ROB_SIZE_WIDTH - 1 : 0] id                 [`LSB_SIZE - 1 : 0];
    reg     [  `LSB_SIZE_WIDTH - 1 : 0] head_id;
    reg     [  `LSB_SIZE_WIDTH - 1 : 0] tail_id;

    wire                                tmp_front_load;
    wire                                tmp_new_load;
    wire                                tmp_new_store;
    wire                                tmp_dequeue_load;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q1;
    reg     [            `XLEN - 1 : 0] tmp_new_V1;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q2;
    reg     [            `XLEN - 1 : 0] tmp_new_V2;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q1;
    reg     [            `XLEN - 1 : 0] tmp_new_updated_V1;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q2;
    reg     [            `XLEN - 1 : 0] tmp_new_updated_V2;

    assign lsb_full         = (head_id == tail_id + `LSB_SIZE_WIDTH'b1);
    assign lsb_empty        = (head_id == tail_id);
    assign lsb_front_op     = op[head_id];
    assign lsb_front_Q1     = Q1[head_id];
    assign lsb_front_V1     = V1[head_id];
    assign lsb_front_Q2     = Q2[head_id];
    assign lsb_front_V2     = V2[head_id];
    assign lsb_front_id     = id[head_id];
    assign tmp_front_load   = (!lsb_empty && (lsb_front_op == `LB || lsb_front_op == `LH || lsb_front_op == `LW || lsb_front_op == `LBU || lsb_front_op == `LHU));
    assign tmp_new_load     = (dec_op == `LB || dec_op == `LH || dec_op == `LW || dec_op == `LBU || dec_op == `LHU);
    assign tmp_new_store    = (dec_op == `SB || dec_op == `SH || dec_op == `SW);
    assign tmp_dequeue_load = (tmp_front_load && !mem_busy && &lsb_front_Q1 && !(lsb_front_V1 == `XLEN'h30000 && (io_buffer_full || lsb_front_id != rob_head_id)));  // lsb_front_Q1 == -1

    initial begin
        lsb_mem_enable = 1'b0;
        lsb_mem_op     = `INST_OP_WIDTH'b0;
        lsb_mem_addr   = `XLEN'b0;
        lsb_mem_id     = `ROB_SIZE_WIDTH'b0;
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            busy[i] = 1'b0;
            op[i]   = `INST_OP_WIDTH'b0;
            Q1[i]   = -`DEPENDENCY_WIDTH'b1;
            V1[i]   = `XLEN'b0;
            Q2[i]   = -`DEPENDENCY_WIDTH'b1;
            V2[i]   = `XLEN'b0;
            id[i]   = `ROB_SIZE_WIDTH'b0;
        end
        head_id            = `LSB_SIZE_WIDTH'b0;
        tail_id            = `LSB_SIZE_WIDTH'b0;
        tmp_new_Q1         = `DEPENDENCY_WIDTH'b0;
        tmp_new_V1         = `XLEN'b0;
        tmp_new_Q2         = `DEPENDENCY_WIDTH'b0;
        tmp_new_V2         = `XLEN'b0;
        tmp_new_updated_Q1 = `DEPENDENCY_WIDTH'b0;
        tmp_new_updated_V1 = `XLEN'b0;
        tmp_new_updated_Q2 = `DEPENDENCY_WIDTH'b0;
        tmp_new_updated_V2 = `XLEN'b0;
    end

    always @(*) begin
        if (&rf_dep1) begin  // rf_dep1 == -1
            tmp_new_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_V1 = rf_val1 + dec_imm;
        end else if (rob_Q1_ready) begin
            tmp_new_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_V1 = rob_Q1_val + dec_imm;
        end else begin
            tmp_new_Q1 = rf_dep1;
            tmp_new_V1 = dec_imm;
        end
        if (mem_data_ready && tmp_new_Q1 == {1'b0, mem_id}) begin
            tmp_new_updated_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V1 = tmp_new_V1 + mem_data;
        end else if (alu_ready && tmp_new_Q1 == {1'b0, alu_id}) begin
            tmp_new_updated_Q1 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V1 = tmp_new_V1 + alu_res;
        end else begin
            tmp_new_updated_Q1 = tmp_new_Q1;
            tmp_new_updated_V1 = tmp_new_V1;
        end
    end

    always @(*) begin
        if (tmp_new_load) begin
            tmp_new_Q2 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_V2 = `XLEN'b0;
        end else if (&rf_dep2) begin  // rf_dep2 == -1
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
        if (mem_data_ready && tmp_new_Q2 == {1'b0, mem_id}) begin
            tmp_new_updated_Q2 = -`DEPENDENCY_WIDTH'b1;
            tmp_new_updated_V2 = mem_data;
        end else if (alu_ready && tmp_new_Q2 == {1'b0, alu_id}) begin
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
                lsb_mem_enable <= 1'b0;
                lsb_mem_op     <= `INST_OP_WIDTH'b0;
                lsb_mem_addr   <= `XLEN'b0;
                lsb_mem_id     <= `ROB_SIZE_WIDTH'b0;
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                    busy[i] <= 1'b0;
                    op[i]   <= `INST_OP_WIDTH'b0;
                    Q1[i]   <= -`DEPENDENCY_WIDTH'b1;
                    V1[i]   <= `XLEN'b0;
                    Q2[i]   <= -`DEPENDENCY_WIDTH'b1;
                    V2[i]   <= `XLEN'b0;
                    id[i]   <= `ROB_SIZE_WIDTH'b0;
                end
                head_id <= `LSB_SIZE_WIDTH'b0;
                tail_id <= `LSB_SIZE_WIDTH'b0;
            end else if (flush) begin
                tail_id        <= head_id;
                lsb_mem_enable <= 1'b0;
            end else begin
                if (!stall && dec_ready && (tmp_new_store || tmp_new_load)) begin
                    busy[tail_id] <= 1'b1;
                    op[tail_id]   <= dec_op;
                    id[tail_id]   <= rob_tail_id;
                    Q1[tail_id]   <= tmp_new_updated_Q1;
                    V1[tail_id]   <= tmp_new_updated_V1;
                    Q2[tail_id]   <= tmp_new_updated_Q2;
                    V2[tail_id]   <= tmp_new_updated_V2;
                    tail_id       <= tail_id + `LSB_SIZE_WIDTH'b1;
                end
                if (mem_data_ready) begin
                    for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                        if (busy[i]) begin
                            if (Q1[i] == {1'b0, mem_id}) begin
                                Q1[i] <= -`DEPENDENCY_WIDTH'b1;
                                V1[i] <= V1[i] + mem_data;
                            end
                            if (Q2[i] == {1'b0, mem_id}) begin
                                Q2[i] <= -`DEPENDENCY_WIDTH'b1;
                                V2[i] <= mem_data;
                            end
                        end
                    end
                end
                if (alu_ready) begin
                    for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                        if (busy[i]) begin
                            if (Q1[i] == {1'b0, alu_id}) begin
                                Q1[i] <= -`DEPENDENCY_WIDTH'b1;
                                V1[i] <= V1[i] + alu_res;
                            end
                            if (Q2[i] == {1'b0, alu_id}) begin
                                Q2[i] <= -`DEPENDENCY_WIDTH'b1;
                                V2[i] <= alu_res;
                            end
                        end
                    end
                end
                lsb_mem_enable <= tmp_dequeue_load;
                lsb_mem_op     <= op[head_id];
                lsb_mem_addr   <= V1[head_id];
                lsb_mem_id     <= id[head_id];
                if (tmp_dequeue_load || rob_mem_enable) begin
                    busy[head_id] <= 1'b0;
                    head_id       <= head_id + `LSB_SIZE_WIDTH'b1;
                end
            end
        end
    end
endmodule
