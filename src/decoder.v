`include "global_params.v"

module decoder (
    // input
    input wire clk,
    input wire flush,

    // from Fetcher
    input wire                 fet_ready,
    input wire [`XLEN - 1 : 0] fet_inst,
    input wire [`XLEN - 1 : 0] fet_inst_addr,
    input wire                 fet_jump_pred,

    // from LSB
    input wire lsb_full,

    // from ROB
    input wire rob_full,

    // from RS
    input wire rs_full,

    // output
    output wire                          stall,
    output reg                           dec_ready,
    output reg  [`INST_OP_WIDTH - 1 : 0] dec_op,
    output reg                           dec_jump_pred,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rd,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rs1,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rs2,
    output reg  [         `XLEN - 1 : 0] dec_imm,
    output reg  [         `XLEN - 1 : 0] dec_inst_addr
);
    wire [`XLEN - 1 : 0] tmp_u_imm;
    wire [`XLEN - 1 : 0] tmp_j_imm;
    wire [`XLEN - 1 : 0] tmp_b_imm;
    wire [`XLEN - 1 : 0] tmp_s_imm;
    wire [`XLEN - 1 : 0] tmp_i_imm;
    reg                  tmp_stall;

    assign stall     = tmp_stall;
    assign tmp_u_imm = {fet_inst[31 : 12], {12{1'b0}}};
    assign tmp_j_imm = {{13{fet_inst[31]}}, fet_inst[19 : 12], fet_inst[20 : 20], fet_inst[30 : 25], fet_inst[24 : 21]};
    assign tmp_b_imm = {{21{fet_inst[31]}}, fet_inst[7 : 7], fet_inst[30 : 25], fet_inst[11 : 8], 1'b0};
    assign tmp_s_imm = {{21{fet_inst[31]}}, fet_inst[30 : 25], fet_inst[11 : 7]};
    assign tmp_i_imm = ((fet_inst[6 : 0] == 7'b0010011 && fet_inst[13 : 12] == 2'b01) ? {{27{1'b0}}, fet_inst[24 : 20]} : {{21{fet_inst[31]}}, fet_inst[30 : 20]});

    initial begin
        dec_ready     = 1'b0;
        dec_op        = `INST_OP_WIDTH'b0;
        dec_jump_pred = 1'b0;
        dec_rd        = `REG_CNT_WIDTH'b0;
        dec_rs1       = `REG_CNT_WIDTH'b0;
        dec_rs2       = `REG_CNT_WIDTH'b0;
        dec_imm       = `XLEN'b0;
        dec_inst_addr = `XLEN'b0;
        tmp_stall     = 1'b0;
    end

    always @(*) begin
        if (!dec_ready) begin
            tmp_stall = 1'b0;
        end else begin
            case (dec_op)
                `LUI, `AUIPC, `JAL: tmp_stall = rob_full;
                `LB, `LH, `LW, `LBU, `LHU, `SB, `SH, `SW: tmp_stall = rob_full || lsb_full;
                default: tmp_stall = rob_full || rs_full;
            endcase
        end
    end

    always @(posedge clk) begin
        if (flush) begin
            dec_ready <= 1'b0;
        end else begin
            if (!stall) begin
                if (!fet_ready) begin
                    dec_ready <= 1'b0;
                end else begin
                    dec_ready     <= 1'b1;
                    dec_inst_addr <= fet_inst_addr;
                    dec_jump_pred <= fet_jump_pred;
                    case (fet_inst[6 : 0])
                        7'b0110111, 7'b0010111: begin
                            dec_rd  <= fet_inst[11 : 7];
                            dec_imm <= tmp_u_imm;
                            dec_rs1 <= `REG_CNT_WIDTH'b0;
                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                        end
                        7'b1101111: begin
                            dec_rd  <= fet_inst[11 : 7];
                            dec_imm <= tmp_j_imm;
                            dec_rs1 <= `REG_CNT_WIDTH'b0;
                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                        end
                        7'b1100011: begin
                            dec_rd  <= `REG_CNT_WIDTH'b0;
                            dec_rs1 <= fet_inst[19 : 15];
                            dec_rs2 <= fet_inst[24 : 20];
                            dec_imm <= tmp_b_imm;
                        end
                        7'b0100011: begin
                            dec_rd  <= `REG_CNT_WIDTH'b0;
                            dec_rs1 <= fet_inst[19 : 15];
                            dec_rs2 <= fet_inst[24 : 20];
                            dec_imm <= tmp_s_imm;
                        end
                        7'b0110011: begin
                            dec_rd  <= fet_inst[11 : 7];
                            dec_rs1 <= fet_inst[19 : 15];
                            dec_rs2 <= fet_inst[24 : 20];
                            dec_imm <= `XLEN'b0;
                        end
                        7'b1100111, 7'b0010011, 7'b0000011: begin
                            dec_imm <= tmp_i_imm;
                            dec_rd  <= fet_inst[11 : 7];
                            dec_rs1 <= fet_inst[19 : 15];
                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                        end
                    endcase
                    case (fet_inst[6 : 0])
                        7'b0110111: dec_op <= `LUI;
                        7'b0010111: dec_op <= `AUIPC;
                        7'b1101111: dec_op <= `JAL;
                        7'b1100111: dec_op <= `JALR;
                        7'b1100011: begin
                            case (fet_inst[14 : 12])
                                3'b000:  dec_op <= `BEQ;
                                3'b001:  dec_op <= `BNE;
                                3'b100:  dec_op <= `BLT;
                                3'b101:  dec_op <= `BGE;
                                3'b110:  dec_op <= `BLTU;
                                3'b111:  dec_op <= `BGEU;
                                default: dec_op <= `INST_OP_WIDTH'b0;
                            endcase
                        end
                        7'b0100011: begin
                            case (fet_inst[14 : 12])
                                3'b000:  dec_op <= `SB;
                                3'b001:  dec_op <= `SH;
                                3'b010:  dec_op <= `SW;
                                default: dec_op <= `INST_OP_WIDTH'b0;
                            endcase
                        end
                        7'b0110011: begin
                            case (fet_inst[14 : 12])
                                3'b000: dec_op <= (fet_inst[30] ? `SUB : `ADD);
                                3'b001: dec_op <= `SLL;
                                3'b010: dec_op <= `SLT;
                                3'b011: dec_op <= `SLTU;
                                3'b100: dec_op <= `XOR;
                                3'b101: dec_op <= (fet_inst[30] ? `SRA : `SRL);
                                3'b110: dec_op <= `OR;
                                3'b111: dec_op <= `AND;
                            endcase
                        end
                        7'b0010011: begin
                            case (fet_inst[14 : 12])
                                3'b000: dec_op <= `ADDI;
                                3'b001: dec_op <= `SLLI;
                                3'b010: dec_op <= `SLTI;
                                3'b011: dec_op <= `SLTIU;
                                3'b100: dec_op <= `XORI;
                                3'b101: dec_op <= (fet_inst[30] ? `SRAI : `SRLI);
                                3'b110: dec_op <= `ORI;
                                3'b111: dec_op <= `ANDI;
                            endcase
                        end
                        7'b0000011: begin
                            case (fet_inst[14 : 12])
                                3'b000:  dec_op <= `LB;
                                3'b001:  dec_op <= `LH;
                                3'b010:  dec_op <= `LW;
                                3'b100:  dec_op <= `LBU;
                                3'b101:  dec_op <= `LHU;
                                default: dec_op <= `INST_OP_WIDTH'b0;
                            endcase
                        end
                        default: dec_op <= `INST_OP_WIDTH'b0;
                    endcase
                end
            end
        end
    end
endmodule
