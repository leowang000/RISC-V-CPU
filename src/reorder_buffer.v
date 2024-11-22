`include "global_params.v"

module reorder_buffer (
    // from RF
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,
    input wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2,

    // from RS
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rs_remove_id,  // the rob id of the instruction being removed from rs

    // output
    output wire                           rob_full,
    output wire                           rob_rs_Q1_ready,
    output wire [          `XLEN - 1 : 0] rob_rs_Q1_val,
    output wire                           rob_rs_Q2_ready,
    output wire [          `XLEN - 1 : 0] rob_rs_Q2_val,
    output wire [  `ALU_OP_WIDTH - 1 : 0] rob_rs_remove_op,
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] rob_head_id,       // [head, tail)
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id
);
    reg  [`INST_TYPE_WIDTH - 1 : 0] op            [`ROB_SIZE - 1 : 0];
    reg  [  `REG_CNT_WIDTH - 1 : 0] rd            [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] val           [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] addr          [`ROB_SIZE - 1 : 0];  // store inst: addr = store address; jump inst: addr = destination
    reg                             ready         [`ROB_SIZE - 1 : 0];
    reg                             jump_pred     [`ROB_SIZE - 1 : 0];
    reg  [           `XLEN - 1 : 0] inst_addr     [`ROB_SIZE - 1 : 0];

    wire                            tmp_rob_empty;

    assign rob_full         = (rob_head_id == rob_tail_id + `ROB_SIZE_WIDTH'b1);
    assign rob_rs_Q1_ready  = (|rf_dep1 ? 1'b0 : ready[rf_dep1[`ROB_SIZE-1 : 0]]);
    assign rob_rs_Q1_val    = (|rf_dep1 ? `XLEN'b0 : val[rf_dep1[`ROB_SIZE-1 : 0]]);
    assign rob_rs_Q2_ready  = (|rf_dep2 ? 1'b0 : ready[rf_dep2[`ROB_SIZE-1 : 0]]);
    assign rob_rs_Q2_val    = (|rf_dep2 ? `XLEN'b0 : val[rf_dep2[`ROB_SIZE-1 : 0]]);
    assign rob_rs_remove_op = op[rs_remove_id];
    assign tmp_rob_empty    = (rob_head_id == rob_tail_id);

    initial begin
        rob_head_id = `ROB_SIZE_WIDTH'b0;
        rob_tail_id = `ROB_SIZE_WIDTH'b0;

    end
endmodule
