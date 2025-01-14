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
    input wire [         `XLEN - 1 : 0] dec_imm,

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
    input wire                           rob_lsb_store_ready,
    input wire [`LSB_SIZE_WIDTH - 1 : 0] rob_lsb_store_id,
    input wire                           rob_Q1_ready,
    input wire [          `XLEN - 1 : 0] rob_Q1_val,
    input wire                           rob_Q2_ready,
    input wire [          `XLEN - 1 : 0] rob_Q2_val,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_head_id,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,

    // output
    output wire                             lsb_full,
    output wire [  `LSB_SIZE_WIDTH - 1 : 0] lsb_tail_id,
    output wire                             lsb_cur_empty,     // to ROB
    output wire [   `INST_OP_WIDTH - 1 : 0] lsb_cur_front_op,  // to ROB
    output wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_cur_front_Q1,  // to ROB
    output wire [            `XLEN - 1 : 0] lsb_cur_front_V1,  // to ROB
    output wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_cur_front_Q2,  // to ROB
    output wire [            `XLEN - 1 : 0] lsb_cur_front_V2,  // to ROB
    output wire [  `ROB_SIZE_WIDTH - 1 : 0] lsb_cur_front_id,  // to ROB
    output reg                              lsb_mem_enable,    // to Memory Controller
    output reg  [   `INST_OP_WIDTH - 1 : 0] lsb_mem_op,        // to Memory Controller
    output reg  [            `XLEN - 1 : 0] lsb_mem_addr,      // to Memory Controller
    output reg  [            `XLEN - 1 : 0] lsb_mem_data,
    output reg  [  `ROB_SIZE_WIDTH - 1 : 0] lsb_mem_id         // to Memory Controller
);
    integer                             i;

    reg                                 busy               [`LSB_SIZE - 1 : 0];
    reg     [   `INST_OP_WIDTH - 1 : 0] op                 [`LSB_SIZE - 1 : 0];
    reg     [`DEPENDENCY_WIDTH - 1 : 0] Q1                 [`LSB_SIZE - 1 : 0];
    reg     [            `XLEN - 1 : 0] V1                 [`LSB_SIZE - 1 : 0];
    reg     [`DEPENDENCY_WIDTH - 1 : 0] Q2                 [`LSB_SIZE - 1 : 0];
    reg     [            `XLEN - 1 : 0] V2                 [`LSB_SIZE - 1 : 0];
    reg     [  `ROB_SIZE_WIDTH - 1 : 0] id                 [`LSB_SIZE - 1 : 0];
    reg                                 store_ready        [`LSB_SIZE - 1 : 0];
    reg     [  `LSB_SIZE_WIDTH - 1 : 0] head_id;
    reg     [  `LSB_SIZE_WIDTH - 1 : 0] tail_id;

    wire                                tmp_lsb_empty;
    wire                                tmp_front_load;
    wire                                tmp_front_store;
    wire                                tmp_new_load;
    wire                                tmp_new_store;
    wire                                tmp_dequeue_load;
    wire                                tmp_dequeue_store;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q1;
    reg     [            `XLEN - 1 : 0] tmp_new_V1;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_Q2;
    reg     [            `XLEN - 1 : 0] tmp_new_V2;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q1;
    reg     [            `XLEN - 1 : 0] tmp_new_updated_V1;
    reg     [`DEPENDENCY_WIDTH - 1 : 0] tmp_new_updated_Q2;
    reg     [            `XLEN - 1 : 0] tmp_new_updated_V2;
    reg     [  `LSB_SIZE_WIDTH - 1 : 0] tmp_cur_head_id;

    assign lsb_full          = (head_id == tail_id + `LSB_SIZE_WIDTH'b1);
    assign lsb_tail_id       = tail_id;
    assign lsb_cur_empty     = (tmp_cur_head_id == tail_id);
    assign lsb_cur_front_op  = op[tmp_cur_head_id];
    assign lsb_cur_front_Q1  = Q1[tmp_cur_head_id];
    assign lsb_cur_front_V1  = V1[tmp_cur_head_id];
    assign lsb_cur_front_Q2  = Q2[tmp_cur_head_id];
    assign lsb_cur_front_V2  = V2[tmp_cur_head_id];
    assign lsb_cur_front_id  = id[tmp_cur_head_id];
    assign tmp_lsb_empty     = (head_id == tail_id);
    assign tmp_front_load    = (!tmp_lsb_empty && (op[head_id] == `LB || op[head_id] == `LH || op[head_id] == `LW || op[head_id] == `LBU || op[head_id] == `LHU));
    assign tmp_front_store   = (!tmp_lsb_empty && (op[head_id] == `SB || op[head_id] == `SH || op[head_id] == `SW));
    assign tmp_new_load      = (dec_op == `LB || dec_op == `LH || dec_op == `LW || dec_op == `LBU || dec_op == `LHU);
    assign tmp_new_store     = (dec_op == `SB || dec_op == `SH || dec_op == `SW);
    assign tmp_dequeue_load  = (tmp_front_load && !mem_busy && &Q1[head_id] && !((V1[head_id] == `XLEN'h30000 || V1[head_id] == `XLEN'h30004) && (io_buffer_full || id[head_id] != rob_head_id)));  // Q1[head_id] == -1
    assign tmp_dequeue_store = (tmp_front_store && !mem_busy && store_ready[head_id] && !((V1[head_id] == `XLEN'h30000 || V1[head_id] == `XLEN'h30004) && io_buffer_full));

`ifdef DEBUG
    wire dbg_store_ready_0;
    wire dbg_store_ready_1;
    wire dbg_store_ready_2;
    wire dbg_store_ready_3;
    wire dbg_store_ready_4;
    wire dbg_store_ready_5;
    wire dbg_store_ready_6;
    wire dbg_store_ready_7;

    assign dbg_store_ready_0 = store_ready[0];
    assign dbg_store_ready_1 = store_ready[1];
    assign dbg_store_ready_2 = store_ready[2];
    assign dbg_store_ready_3 = store_ready[3];
    assign dbg_store_ready_4 = store_ready[4];
    assign dbg_store_ready_5 = store_ready[5];
    assign dbg_store_ready_6 = store_ready[6];
    assign dbg_store_ready_7 = store_ready[7];

    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_0;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_3;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_4;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_5;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_6;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q1_7;

    assign dbg_Q1_0 = Q1[0];
    assign dbg_Q1_1 = Q1[1];
    assign dbg_Q1_2 = Q1[2];
    assign dbg_Q1_3 = Q1[3];
    assign dbg_Q1_4 = Q1[4];
    assign dbg_Q1_5 = Q1[5];
    assign dbg_Q1_6 = Q1[6];
    assign dbg_Q1_7 = Q1[7];

    wire [`XLEN - 1 : 0] dbg_V1_0;
    wire [`XLEN - 1 : 0] dbg_V1_1;
    wire [`XLEN - 1 : 0] dbg_V1_2;
    wire [`XLEN - 1 : 0] dbg_V1_3;
    wire [`XLEN - 1 : 0] dbg_V1_4;
    wire [`XLEN - 1 : 0] dbg_V1_5;
    wire [`XLEN - 1 : 0] dbg_V1_6;
    wire [`XLEN - 1 : 0] dbg_V1_7;

    assign dbg_V1_0 = V1[0];
    assign dbg_V1_1 = V1[1];
    assign dbg_V1_2 = V1[2];
    assign dbg_V1_3 = V1[3];
    assign dbg_V1_4 = V1[4];
    assign dbg_V1_5 = V1[5];
    assign dbg_V1_6 = V1[6];
    assign dbg_V1_7 = V1[7];

    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_0;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_3;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_4;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_5;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_6;
    wire [`DEPENDENCY_WIDTH - 1 : 0] dbg_Q2_7;

    assign dbg_Q2_0 = Q2[0];
    assign dbg_Q2_1 = Q2[1];
    assign dbg_Q2_2 = Q2[2];
    assign dbg_Q2_3 = Q2[3];
    assign dbg_Q2_4 = Q2[4];
    assign dbg_Q2_5 = Q2[5];
    assign dbg_Q2_6 = Q2[6];
    assign dbg_Q2_7 = Q2[7];

    wire [`XLEN - 1 : 0] dbg_V2_0;
    wire [`XLEN - 1 : 0] dbg_V2_1;
    wire [`XLEN - 1 : 0] dbg_V2_2;
    wire [`XLEN - 1 : 0] dbg_V2_3;
    wire [`XLEN - 1 : 0] dbg_V2_4;
    wire [`XLEN - 1 : 0] dbg_V2_5;
    wire [`XLEN - 1 : 0] dbg_V2_6;
    wire [`XLEN - 1 : 0] dbg_V2_7;

    assign dbg_V2_0 = V2[0];
    assign dbg_V2_1 = V2[1];
    assign dbg_V2_2 = V2[2];
    assign dbg_V2_3 = V2[3];
    assign dbg_V2_4 = V2[4];
    assign dbg_V2_5 = V2[5];
    assign dbg_V2_6 = V2[6];
    assign dbg_V2_7 = V2[7];

    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_0;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_1;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_2;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_3;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_4;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_5;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_6;
    wire [`ROB_SIZE_WIDTH - 1 : 0] dbg_id_7;

    assign dbg_id_0 = id[0];
    assign dbg_id_1 = id[1];
    assign dbg_id_2 = id[2];
    assign dbg_id_3 = id[3];
    assign dbg_id_4 = id[4];
    assign dbg_id_5 = id[5];
    assign dbg_id_6 = id[6];
    assign dbg_id_7 = id[7];

    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_0;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_1;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_2;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_3;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_4;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_5;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_6;
    wire [`INST_OP_WIDTH - 1 : 0] dbg_op_7;

    assign dbg_op_0 = op[0];
    assign dbg_op_1 = op[1];
    assign dbg_op_2 = op[2];
    assign dbg_op_3 = op[3];
    assign dbg_op_4 = op[4];
    assign dbg_op_5 = op[5];
    assign dbg_op_6 = op[6];
    assign dbg_op_7 = op[7];
`endif

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

    always @(*) begin
        tmp_cur_head_id = head_id;
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (store_ready[i] && !store_ready[(i+`LSB_SIZE_WIDTH'd1)&{`LSB_SIZE_WIDTH{1'b1}}]) begin
                tmp_cur_head_id = (i + `LSB_SIZE_WIDTH'd1) & {`LSB_SIZE_WIDTH{1'b1}};
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            lsb_mem_enable <= 1'b0;
            lsb_mem_op     <= `INST_OP_WIDTH'b0;
            lsb_mem_addr   <= `XLEN'b0;
            lsb_mem_id     <= `ROB_SIZE_WIDTH'b0;
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i]        <= 1'b0;
                op[i]          <= `INST_OP_WIDTH'b0;
                Q1[i]          <= -`DEPENDENCY_WIDTH'b1;
                V1[i]          <= `XLEN'b0;
                Q2[i]          <= -`DEPENDENCY_WIDTH'b1;
                V2[i]          <= `XLEN'b0;
                id[i]          <= `ROB_SIZE_WIDTH'b0;
                store_ready[i] <= 1'b0;
            end
            head_id <= `LSB_SIZE_WIDTH'b0;
            tail_id <= `LSB_SIZE_WIDTH'b0;
        end else if (rdy) begin
            if (flush) begin  // TODO
                lsb_mem_enable <= 1'b0;
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                    busy[i] <= store_ready[i];
                end
                tail_id <= tmp_cur_head_id;
            end else begin
                if (rob_lsb_store_ready) begin
                    store_ready[rob_lsb_store_id] <= 1'b1;
                end
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
                if (tmp_dequeue_load || tmp_dequeue_store) begin
                    lsb_mem_enable       <= 1'b1;
                    lsb_mem_op           <= op[head_id];
                    lsb_mem_addr         <= V1[head_id];
                    lsb_mem_data         <= V2[head_id];
                    lsb_mem_id           <= id[head_id];
                    busy[head_id]        <= 1'b0;
                    store_ready[head_id] <= 1'b0;
                    head_id              <= head_id + `LSB_SIZE_WIDTH'b1;
                end else begin
                    lsb_mem_enable <= 1'b0;
                    lsb_mem_op     <= `INST_OP_WIDTH'b0;
                    lsb_mem_addr   <= `XLEN'b0;
                    lsb_mem_data   <= `XLEN'b0;
                    lsb_mem_id     <= `ROB_SIZE_WIDTH'b0;
                end
            end
        end
    end
endmodule
