`include "global_params.v"

module alu (
    // input
    input wire clk,
    input wire flush,

    // from RS
    input wire                         rs_ready,
    input wire [`ALU_OP_WIDTH - 1 : 0] rs_op,
    input wire [        `XLEN - 1 : 0] rs_val_1,
    input wire [        `XLEN - 1 : 0] rs_val_2,

    // output
    output reg [`XLEN - 1 : 0] result,
    output reg                 ready
);
    initial begin
        result = `XLEN'b0;
        ready  = 1'b0;
    end

    function [`XLEN - 1 : 0] calculate;
        input [`ALU_OP_WIDTH - 1 : 0] rs_op;
        input [`XLEN - 1 : 0] rs_val_1;
        input [`XLEN - 1 : 0] rs_val_2;
        begin
            case (rs_op)
                `ALU_ADD: calculate = rs_val_1 + rs_val_2;
                `ALU_SUB: calculate = rs_val_1 - rs_val_2;
                `ALU_AND: calculate = rs_val_1 & rs_val_2;
                `ALU_OR: calculate = rs_val_1 | rs_val_2;
                `ALU_XOR: calculate = rs_val_1 ^ rs_val_2;
                `ALU_SHL: calculate = rs_val_1 << rs_val_2;
                `ALU_SHR: calculate = rs_val_1 >> rs_val_2;
                `ALU_SHRA: calculate = rs_val_1 >>> rs_val_2;
                `ALU_EQ: calculate = (rs_val_1 == rs_val_2) ? `XLEN'b1 : `XLEN'b0;
                `ALU_NEQ: calculate = (rs_val_1 != rs_val_2) ? `XLEN'b1 : `XLEN'b0;
                `ALU_LT: calculate = ($signed(rs_val_1) < $signed(rs_val_2)) ? `XLEN'b1 : `XLEN'b0;
                `ALU_LTU:
                calculate = ($unsigned(rs_val_1) < $unsigned(rs_val_2)) ? `XLEN'b1 : `XLEN'b0;
                `ALU_GE: calculate = ($signed(rs_val_1) >= $signed(rs_val_2)) ? `XLEN'b1 : `XLEN'b0;
                `ALU_GEU:
                calculate = ($unsigned(rs_val_1) >= $unsigned(rs_val_2)) ? `XLEN'b1 : `XLEN'b0;
                default: calculate = `XLEN'b0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (flush || !rs_ready) begin
            result <= `XLEN'b0;
            ready  <= 1'b0;
        end else begin
            result <= calculate(rs_op, rs_val_1, rs_val_2);
            ready  <= 1'b1;
        end
    end
endmodule
