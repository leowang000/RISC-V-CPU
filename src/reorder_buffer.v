`include "global_params.v"

module reorder_buffer (
    // input
    input wire clk,
    input wire flush,
    input wire stall,

    // from ALU
    input wire                           alu_ready,
    input wire [          `XLEN - 1 : 0] alu_res,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] alu_id,     // the rob id of the instruction being calculated

    // from Decoder
    input wire                            dec_ready,
    input wire [`INST_TYPE_WIDTH - 1 : 0] dec_op,
    input wire                            dec_jump_pred,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rd,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rs1,
    input wire [  `REG_CNT_WIDTH - 1 : 0] dec_rs2,
    input wire [           `XLEN - 1 : 0] dec_imm,
    input wire [           `XLEN - 1 : 0] dec_inst_addr,

    // from LSB
    input wire                             lsb_empty,
    input wire [ `INST_TYPE_WIDTH - 1 : 0] lsb_front_op,
    input wire [  `ROB_SIZE_WIDTH - 1 : 0] lsb_front_id,
    input wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q1,
    input wire [            `XLEN - 1 : 0] lsb_front_V1,
    input wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q2,
    input wire [            `XLEN - 1 : 0] lsb_front_V2,

    // from Memory Controller
    input wire                           mem_busy,
    input wire                           mem_data_ready,
    input wire [          `XLEN - 1 : 0] mem_data,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] mem_id,

    // from RF
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,  // dependency of register dec_rs1
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2,  // dependency of register dec_rs2

    // from RS
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rs_remove_id,  // the rob id of the instruction being removed from rs

    // output
    output wire                            rob_full,
    output wire                            rob_Q1_ready,      // to LSB and RS
    output wire [           `XLEN - 1 : 0] rob_Q1_val,        // to LSB and RS
    output wire                            rob_Q2_ready,      // to LSB and RS
    output wire [           `XLEN - 1 : 0] rob_Q2_val,        // to LSB and RS
    output wire [   `ALU_OP_WIDTH - 1 : 0] rob_rs_remove_op,  // to RS
    output reg  [ `ROB_SIZE_WIDTH - 1 : 0] rob_head_id,       // range: [head, tail)
    output reg  [ `ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,
    output reg                             rob_flush,
    output reg  [           `XLEN - 1 : 0] rob_correct_pc,    // the correct branch destination
    output reg                             rob_bp_enable,     // to Branch Predictor
    output reg  [           `XLEN - 1 : 0] rob_bp_inst_addr,  // to Branch Predictor
    output reg                             rob_bp_jump,       // to Branch Predictor
    output reg                             rob_bp_correct,    // to Branch Predictor
    output reg                             rob_store_enable,  // to Memory Controller
    output reg  [`INST_TYPE_WIDTH - 1 : 0] rob_store_op,      // to Memory Controller
    output reg  [           `XLEN - 1 : 0] rob_store_addr,    // to Memory Controller
    output reg  [           `XLEN - 1 : 0] rob_store_val,     // to Memory Controller
    output reg                             rob_write_enable,  // to RF
    output reg  [  `REG_CNT_WIDTH - 1 : 0] rob_write_rd,      // to RF
    output reg  [           `XLEN - 1 : 0] rob_write_val      // to RF
);
    reg  [`INST_TYPE_WIDTH - 1 : 0] op                   [`ROB_SIZE - 1 : 0];
    reg  [  `REG_CNT_WIDTH - 1 : 0] rd                   [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] val                  [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] addr                 [`ROB_SIZE - 1 : 0];  // store inst: addr = store address; branch inst: addr = destination
    reg                             ready                [`ROB_SIZE - 1 : 0];
    reg                             jump_pred            [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] inst_addr            [`ROB_SIZE - 1 : 0];

    wire                            tmp_rob_empty;
    wire                            tmp_lsb_front_store;
    wire                            tmp_rob_front_store;
    wire                            tmp_rob_front_branch;
    wire                            tmp_commit;
    wire                            tmp_flush;
    wire [           `XLEN - 1 : 0] tmp_correct_pc;

    assign rob_full             = (rob_head_id == rob_tail_id + `ROB_SIZE_WIDTH'b1);
    assign rob_Q1_ready         = (|rf_dep1 ? 1'b0 : ready[rf_dep1[`ROB_SIZE-1 : 0]]);
    assign rob_Q1_val           = (|rf_dep1 ? `XLEN'b0 : val[rf_dep1[`ROB_SIZE-1 : 0]]);
    assign rob_Q2_ready         = (|rf_dep2 ? 1'b0 : ready[rf_dep2[`ROB_SIZE-1 : 0]]);
    assign rob_Q2_val           = (|rf_dep2 ? `XLEN'b0 : val[rf_dep2[`ROB_SIZE-1 : 0]]);
    assign rob_rs_remove_op     = op[rs_remove_id];
    assign tmp_rob_empty        = (rob_head_id == rob_tail_id);
    assign tmp_lsb_front_store  = (!lsb_empty && (lsb_front_op == `SB || lsb_front_op == `SH || lsb_front_op == `SW));
    assign tmp_rob_front_store  = (!tmp_rob_empty && (op[rob_head_id] == `SB || op[rob_head_id] == `SH || op[rob_head_id] == `SW));
    assign tmp_rob_front_branch = (!tmp_rob_empty && (op[rob_head_id] == `BEQ || op[rob_head_id] == `BNE || op[rob_head_id] == `BLT || op[rob_head_id] == `BLTU || op[rob_head_id] == `BGE || op[rob_head_id] == `BGEU));
    assign tmp_commit           = (!tmp_rob_empty && ready[rob_head_id] && (!tmp_rob_front_store && (mem_busy || rob_store_enable)));
    assign tmp_flush            = (tmp_rob_front_branch ? jump_pred[rob_head_id] != val[rob_head_id][0 : 0] : op[rob_head_id] == `JALR);
    assign tmp_correct_pc       = (tmp_rob_front_branch ? (val[rob_head_id] ? addr[rob_head_id] : inst_addr[rob_head_id] + `XLEN'd4) : addr[rob_head_id]);

    initial begin
        rob_head_id      = `ROB_SIZE_WIDTH'b0;
        rob_tail_id      = `ROB_SIZE_WIDTH'b0;
        rob_flush        = 1'b0;
        rob_correct_pc   = `XLEN'b0;
        rob_write_enable = 1'b0;
        rob_write_rd     = `REG_CNT_WIDTH'b0;
        rob_write_val    = `XLEN'b0;
        rob_store_enable = 1'b0;
        rob_store_op     = `INST_TYPE_WIDTH'b0;
        rob_store_addr   = `XLEN'b0;
        rob_store_val    = `XLEN'b0;
        for (integer i = 0; i < `ROB_SIZE; i = i + 1) begin
            op[i]        = `INST_TYPE_WIDTH'b0;
            rd[i]        = `REG_CNT_WIDTH'b0;
            val[i]       = `XLEN'b0;
            addr[i]      = `XLEN'b0;
            ready[i]     = 1'b0;
            jump_pred[i] = 1'b0;
            inst_addr[i] = `XLEN'b0;
        end
    end

    always @(posedge clk) begin
        if (flush) begin
            rob_tail_id      <= rob_head_id;
            rob_write_enable <= 1'b0;
            rob_store_enable <= 1'b0;
            rob_flush        <= 1'b0;
        end else begin
            if (!stall && dec_ready) begin
                op[rob_tail_id]        <= dec_op;
                jump_pred[rob_tail_id] <= dec_jump_pred;
                rd[rob_tail_id]        <= dec_rd;
                inst_addr[rob_tail_id] <= dec_inst_addr;
                case (dec_op)
                    `LUI: begin
                        ready[rob_tail_id] <= 1'b1;
                        val[rob_tail_id]   <= dec_imm;
                    end
                    `AUIPC: begin
                        ready[rob_tail_id] <= 1'b1;
                        val[rob_tail_id]   <= dec_inst_addr + dec_imm;
                    end
                    `JAL: begin
                        ready[rob_tail_id] <= 1'b1;
                        val[rob_tail_id]   <= dec_inst_addr + `XLEN'd4;
                    end
                    `JALR: val[rob_tail_id] <= dec_inst_addr + `XLEN'd4;
                    `BEQ, `BNE, `BLT, `BLTU, `BGE, `BGEU: addr[rob_tail_id] <= dec_inst_addr + dec_imm;
                    default: ;
                endcase
                rob_tail_id <= rob_tail_id + `ROB_SIZE_WIDTH'b1;
            end
            if (mem_data_ready) begin
                val[mem_id]   <= mem_data;
                ready[mem_id] <= 1'b1;
            end
            if (alu_ready) begin
                if (op[alu_id] == `JALR) begin
                    addr[alu_id] <= alu_res;
                end else begin
                    val[alu_id] <= alu_res;
                end
                ready[alu_id] <= 1'b1;
            end
            if (tmp_lsb_front_store && |lsb_front_Q1 && |lsb_front_Q2) begin  // tmp_lsb_front_store && lsb_front_Q1 == -1 && lsb_front_Q2 == -1
                addr[lsb_front_id]  <= lsb_front_V1;
                val[lsb_front_id]   <= lsb_front_V2;
                ready[lsb_front_id] <= 1'b1;
            end
            if (!tmp_commit || tmp_rob_front_branch || tmp_rob_front_store) begin
                rob_write_enable <= 1'b0;
            end else begin
                rob_write_enable <= 1'b1;
                rob_write_rd     <= rd[rob_head_id];
                rob_write_val    <= val[rob_head_id];
            end
            if (!tmp_commit || !tmp_rob_front_store) begin
                rob_store_enable <= 1'b0;
            end else begin
                rob_store_enable <= 1'b1;
                rob_store_op     <= op[rob_head_id];
                rob_store_addr   <= addr[rob_head_id];
                rob_store_val    <= val[rob_head_id];
            end
            if (tmp_commit) begin
                rob_flush      <= tmp_flush;
                rob_correct_pc <= tmp_correct_pc;
                rob_head_id    <= rob_head_id + `ROB_SIZE_WIDTH'b1;
            end else begin
                rob_flush <= 1'b0;
            end
            if (tmp_commit && tmp_rob_front_branch) begin
                rob_bp_enable    <= 1'b1;
                rob_bp_inst_addr <= inst_addr[rob_head_id];
                rob_bp_jump      <= val[rob_head_id][0:0];
                rob_bp_correct   <= !tmp_flush;
            end else begin
                rob_bp_enable <= 1'b0;
            end
        end
    end
endmodule
