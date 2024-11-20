`include "global_params.v"

module register_file (
    // input
    input wire clk,
    input wire flush,
    input wire stall,

    // from Decoder
    input wire                            decoder_ready,
    input wire [`INST_TYPE_WIDTH - 1 : 0] decoder_inst_type,
    input wire [  `REG_CNT_WIDTH - 1 : 0] decoder_rd,

    // from ROB
    input wire                           rob_ready,
    input wire [ `REG_CNT_WIDTH - 1 : 0] rob_rd,
    input wire [          `XLEN - 1 : 0] rob_val,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_head_id,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rob_tail_id,

    // output
    output wire [          `XLEN * `REG_CNT - 1 : 0] reg_value,          // [i * `XLEN + `XLEN - 1 : i * `XLEN] for value[i]
    output wire [`ROB_SIZE_WIDTH * `REG_CNT - 1 : 0] reg_dependency,     // [i * `ROB_SIZE_WIDTH + `ROB_SIZE_WIDTH - 1 : i * `ROB_SIZE_WIDTH] for dependency[i]
    output wire [                  `REG_CNT - 1 : 0] reg_has_dependency  // [i] for has_dependency[i]
);
    reg [          `XLEN - 1 : 0] value         [`REG_CNT - 1 : 0];
    reg [`ROB_SIZE_WIDTH - 1 : 0] dependency    [`REG_CNT - 1 : 0];
    reg                           has_dependency[`REG_CNT - 1 : 0];

    genvar i;
    generate
        assign reg_value[`XLEN-1 : 0]                                         = `XLEN'b0;
        assign {reg_has_dependency[0], reg_dependency[`ROB_SIZE_WIDTH-1 : 0]} = {1'b0, `ROB_SIZE_WIDTH'b0};
        for (i = 1; i < `REG_CNT; i = i + 1) begin
            assign reg_value[i*`XLEN+`XLEN-1 : i*`XLEN] = (rob_ready && rob_rd == i) ? rob_val : value[i];
            assign {reg_has_dependency[i], reg_dependency[i * `ROB_SIZE_WIDTH + `ROB_SIZE_WIDTH - 1 : i * `ROB_SIZE_WIDTH]} = 
                (rob_ready && rob_rd == i && rob_head_id - `ROB_SIZE_WIDTH'b1 == dependency[i]) ? {1'b0, `ROB_SIZE_WIDTH'b0} : 
                {has_dependency[i], dependency[i]};
        end
    endgenerate

    initial begin
        for (integer i = 0; i < `REG_CNT; i = i + 1) begin
            value[i]                           = `XLEN'b0;
            {has_dependency[i], dependency[i]} = {1'b0, `ROB_SIZE_WIDTH'b0};
        end
    end

    always @(posedge clk) begin
        if (flush) begin
            for (integer i = 0; i < `REG_CNT; i = i + 1) begin
                {has_dependency[i], dependency[i]} <= {1'b0, `ROB_SIZE_WIDTH'b0};
            end
        end else begin
            if (rob_ready && rob_rd != `REG_CNT_WIDTH'b0) begin
                value[rob_rd] <= rob_val;
                if (rob_head_id - `ROB_SIZE_WIDTH'b1 == dependency[rob_rd]) begin
                    {has_dependency[rob_rd], dependency[rob_rd]} <= {1'b0, `ROB_SIZE_WIDTH'b0};
                end
            end
            if (!stall && decoder_ready && decoder_rd != 0) begin
                case (decoder_inst_type)
                    `HALT: ;
                    `BEQ: ;
                    `BNE: ;
                    `BLT: ;
                    `BGE: ;
                    `BLTU: ;
                    `SB: ;
                    `SH: ;
                    `SW: ;
                    default: {has_dependency[decoder_rd], dependency[decoder_rd]} <= {1'b1, rob_tail_id};
                endcase
            end
        end
    end
endmodule
