`include "global_params.v"

module register_file (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,

    // from Decoder
    input wire                          dec_ready,
    input wire [`INST_OP_WIDTH - 1 : 0] dec_op,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rd,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rs1,
    input wire [`REG_CNT_WIDTH - 1 : 0] dec_rs2,

    // from ROB
    input wire                           rob_rf_enable,
    input wire [ `REG_CNT_WIDTH - 1 : 0] rob_rf_rd,
    input wire [          `XLEN - 1 : 0] rob_rf_val,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_head_id,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,

    // output
    output wire [            `XLEN - 1 : 0] rf_val1,  // value of register dec_rs1
    output wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1,  // dependency of register dec_rs1
    output wire [            `XLEN - 1 : 0] rf_val2,  // value of register dec_rs2
    output wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2   // dependency of register dec_rs2
);
    reg [            `XLEN - 1 : 0] val[`REG_CNT - 1 : 0];
    reg [`DEPENDENCY_WIDTH - 1 : 0] dep[`REG_CNT - 1 : 0];

    assign rf_val1 = (dec_rs1 == `REG_CNT_WIDTH'b0 ? `XLEN'b0 : (rob_rf_enable && rob_rf_rd == dec_rs1 ? rob_rf_val : val[dec_rs1]));
    assign rf_val2 = (dec_rs2 == `REG_CNT_WIDTH'b0 ? `XLEN'b0 : (rob_rf_enable && rob_rf_rd == dec_rs2 ? rob_rf_val : val[dec_rs2]));
    assign rf_dep1 = (dec_rs1 == `REG_CNT_WIDTH'b0 || (rob_rf_enable && rob_rf_rd == dec_rs1 && rob_head_id - `ROB_SIZE_WIDTH'b1 == dep[dec_rs1][`ROB_SIZE_WIDTH-1 : 0]) ? -`DEPENDENCY_WIDTH'b1 : dep[dec_rs1]);
    assign rf_dep2 = (dec_rs2 == `REG_CNT_WIDTH'b0 || (rob_rf_enable && rob_rf_rd == dec_rs2 && rob_head_id - `ROB_SIZE_WIDTH'b1 == dep[dec_rs2][`ROB_SIZE_WIDTH-1 : 0]) ? -`DEPENDENCY_WIDTH'b1 : dep[dec_rs2]);

    initial begin
        for (integer i = 0; i < `REG_CNT; i = i + 1) begin
            val[i] = `XLEN'b0;
            dep[i] = -`DEPENDENCY_WIDTH'b1;
        end
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst) begin
                for (integer i = 0; i < `REG_CNT; i = i + 1) begin
                    val[i] <= `XLEN'b0;
                    dep[i] <= -`DEPENDENCY_WIDTH'b1;
                end
            end else if (flush) begin
                for (integer i = 0; i < `REG_CNT; i = i + 1) begin
                    dep[i] <= -`DEPENDENCY_WIDTH'b1;
                end
            end else begin
                if (rob_rf_enable && rob_rf_rd != `REG_CNT_WIDTH'b0) begin
                    val[rob_rf_rd] <= rob_rf_val;
                    if (rob_head_id - `ROB_SIZE_WIDTH'b1 == dep[rob_rf_rd]) begin
                        dep[rob_rf_rd] <= -`DEPENDENCY_WIDTH'b1;
                    end
                end
                if (!stall && dec_ready && dec_rd != 0) begin
                    case (dec_op)
                        `BEQ, `BNE, `BLT, `BGE, `BLTU, `SB, `SH, `SW: ;
                        default: dep[dec_rd] <= {1'b0, rob_tail_id};
                    endcase
                end
            end
        end

    end
endmodule
