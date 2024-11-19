`include "global_params.v"

module alu (
    input  wire        clk,
    input  wire        flush,
    input  wire        enable,
    input  wire [ 3:0] op,
    input  wire [31:0] value_1,
    input  wire [31:0] value_2,
    output reg  [31:0] result,
    output reg         ready
);
    function [31:0] calculate;
        input [3:0] op;
        input [31:0] value_1;
        input [31:0] value_2;
        begin
            case (op)
                `ALU_ADD:  calculate = value_1 + value_2;
                `ALU_SUB:  calculate = value_1 - value_2;
                `ALU_AND:  calculate = value_1 & value_2;
                `ALU_OR:   calculate = value_1 | value_2;
                `ALU_XOR:  calculate = value_1 ^ value_2;
                `ALU_SHL:  calculate = value_1 << value_2;
                `ALU_SHR:  calculate = value_1 >> value_2;
                `ALU_SHRA: calculate = value_1 >>> value_2;
                `ALU_EQ:   calculate = (value_1 == value_2) ? 32'b1 : 32'b0;
                `ALU_NEQ:  calculate = (value_1 != value_2) ? 32'b1 : 32'b0;
                `ALU_LT:   calculate = ($signed(value_1) < $signed(value_2)) ? 32'b1 : 32'b0;
                `ALU_LTU:  calculate = ($unsigned(value_1) < $unsigned(value_2)) ? 32'b1 : 32'b0;
                `ALU_GE:   calculate = ($signed(value_1) >= $signed(value_2)) ? 32'b1 : 32'b0;
                `ALU_GEU:  calculate = ($unsigned(value_1) >= $unsigned(value_2)) ? 32'b1 : 32'b0;
                default:   calculate = 32'b0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (flush || !enable) begin
            result <= 32'b0;
            ready  <= 1'b0;
        end else begin
            result <= calculate(op, value_1, value_2);
            ready  <= 1'b1;
        end
    end

    initial begin
        result = 32'b0;
        ready  = 1'b0;
    end
endmodule
