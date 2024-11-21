`include "global_params.v"

module alu (
    // input
    input wire clk,
    input wire flush,

    // from RS
    input wire                           rs_ready,
    input wire [  `ALU_OP_WIDTH - 1 : 0] rs_op,
    input wire [          `XLEN - 1 : 0] rs_val1,
    input wire [          `XLEN - 1 : 0] rs_val2,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] rs_id,     // the rob id of the instruction being calculated

    // output
    output reg                           alu_ready,
    output reg [          `XLEN - 1 : 0] alu_res,
    output reg [`ROB_SIZE_WIDTH - 1 : 0] alu_id      // the rob id of the instruction being calculated
);
    initial begin
        alu_res   = `XLEN'b0;
        alu_ready = 1'b0;
    end

    function [`XLEN - 1 : 0] calculate;
        input [`ALU_OP_WIDTH - 1 : 0] rs_op;
        input [`XLEN - 1 : 0] rs_val1;
        input [`XLEN - 1 : 0] rs_val2;
        begin
            case (rs_op)
                `ALU_ADD:  calculate = rs_val1 + rs_val2;
                `ALU_SUB:  calculate = rs_val1 - rs_val2;
                `ALU_AND:  calculate = rs_val1 & rs_val2;
                `ALU_OR:   calculate = rs_val1 | rs_val2;
                `ALU_XOR:  calculate = rs_val1 ^ rs_val2;
                `ALU_SHL:  calculate = rs_val1 << rs_val2;
                `ALU_SHR:  calculate = rs_val1 >> rs_val2;
                `ALU_SHRA: calculate = rs_val1 >>> rs_val2;
                `ALU_EQ:   calculate = (rs_val1 == rs_val2) ? `XLEN'b1 : `XLEN'b0;
                `ALU_NEQ:  calculate = (rs_val1 != rs_val2) ? `XLEN'b1 : `XLEN'b0;
                `ALU_LT:   calculate = ($signed(rs_val1) < $signed(rs_val2)) ? `XLEN'b1 : `XLEN'b0;
                `ALU_LTU:  calculate = (rs_val1 < rs_val2) ? `XLEN'b1 : `XLEN'b0;
                `ALU_GE:   calculate = ($signed(rs_val1) >= $signed(rs_val2)) ? `XLEN'b1 : `XLEN'b0;
                `ALU_GEU:  calculate = (rs_val1 >= rs_val2) ? `XLEN'b1 : `XLEN'b0;
                default:   calculate = `XLEN'b0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (flush || !rs_ready) begin
            alu_ready <= 1'b0;
            alu_res   <= `XLEN'b0;
            alu_id    <= `ROB_SIZE_WIDTH'b0;
        end else begin
            alu_ready <= 1'b1;
            alu_res   <= calculate(rs_op, rs_val1, rs_val2);
            alu_id    <= rs_id;
        end
    end
endmodule
