`include "global_params.v"

module decoder (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
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
    output wire                          dec_stall,
    output reg                           dec_ready,
    output reg  [`INST_OP_WIDTH - 1 : 0] dec_op,
    output reg                           dec_jump_pred,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rd,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rs1,
    output reg  [`REG_CNT_WIDTH - 1 : 0] dec_rs2,
    output reg  [         `XLEN - 1 : 0] dec_imm,
    output reg  [         `XLEN - 1 : 0] dec_inst_addr,
    output reg                           dec_c_extension
);
    reg tmp_stall;

    assign dec_stall = tmp_stall;

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
        if (rst) begin
            dec_ready       <= 1'b0;
            dec_op          <= `INST_OP_WIDTH'b0;
            dec_jump_pred   <= 1'b0;
            dec_rd          <= `REG_CNT_WIDTH'b0;
            dec_rs1         <= `REG_CNT_WIDTH'b0;
            dec_rs2         <= `REG_CNT_WIDTH'b0;
            dec_imm         <= `XLEN'b0;
            dec_inst_addr   <= `XLEN'b0;
            dec_c_extension <= 1'b0;
        end else if (rdy) begin
            if (flush) begin
                dec_ready <= 1'b0;
            end else if (!tmp_stall) begin
                if (!fet_ready) begin
                    dec_ready <= 1'b0;
                end else begin
                    dec_ready       <= 1'b1;
                    dec_inst_addr   <= fet_inst_addr;
                    dec_jump_pred   <= fet_jump_pred;
                    dec_c_extension <= (fet_inst[1 : 0] != 2'b11);
                    case (fet_inst[1 : 0])
                        2'b00: begin
                            case (fet_inst[15 : 13])
                                3'b000: begin  // C.ADDI4SPN
                                    dec_op  <= `ADDI;
                                    dec_rd  <= {2'b01, fet_inst[4 : 2]};
                                    dec_rs1 <= `REG_CNT_WIDTH'd2;  // sp
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {22'b0, fet_inst[10 : 7], fet_inst[12 : 11], fet_inst[5 : 5], fet_inst[6 : 6], 2'b00};
                                end
                                3'b010: begin  // C.LW
                                    dec_op  <= `LW;
                                    dec_rd  <= {2'b01, fet_inst[4 : 2]};
                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {25'b0, fet_inst[5 : 5], fet_inst[12 : 10], fet_inst[6 : 6], 2'b00};
                                end
                                3'b110: begin  // C.SW
                                    dec_op  <= `SW;
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                    dec_rs2 <= {2'b01, fet_inst[4 : 2]};
                                    dec_imm <= {25'b0, fet_inst[5 : 5], fet_inst[12 : 10], fet_inst[6 : 6], 2'b00};
                                end
                                default: begin
                                    dec_op  <= `INST_OP_WIDTH'b0;
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= `XLEN'b0;
                                end
                            endcase
                        end
                        2'b01: begin
                            case (fet_inst[15 : 13])
                                3'b000: begin  // C.ADDI
                                    dec_op  <= `ADDI;
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= fet_inst[11 : 7];
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {{27{fet_inst[12]}}, fet_inst[6 : 2]};
                                end
                                3'b001: begin  // C.JAL
                                    dec_op  <= `JAL;
                                    dec_rd  <= `REG_CNT_WIDTH'd1;  // ra
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {{21{fet_inst[12]}}, fet_inst[8 : 8], fet_inst[10 : 9], fet_inst[6 : 6], fet_inst[7 : 7], fet_inst[2 : 2], fet_inst[11 : 11], fet_inst[5 : 3], 1'b0};
                                end
                                3'b010: begin  // C.LI
                                    dec_op  <= `ADDI;
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= `REG_CNT_WIDTH'd0;  // x0
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {{27{fet_inst[12]}}, fet_inst[6 : 2]};
                                end
                                3'b011: begin
                                    if (fet_inst[11 : 7] == `REG_CNT_WIDTH'd2) begin  // C.ADDI16SP
                                        dec_op  <= `ADDI;
                                        dec_rd  <= `REG_CNT_WIDTH'd2;  // sp
                                        dec_rs1 <= `REG_CNT_WIDTH'd2;  // sp
                                        dec_rs2 <= `REG_CNT_WIDTH'b0;
                                        dec_imm <= {{23{fet_inst[12]}}, fet_inst[4 : 3], fet_inst[5 : 5], fet_inst[2 : 2], fet_inst[6 : 6], 4'b0};
                                    end else begin  // C.LUI
                                        dec_op  <= `ADDI;
                                        dec_rd  <= fet_inst[11 : 7];
                                        dec_rs1 <= `REG_CNT_WIDTH'b0;
                                        dec_rs2 <= `REG_CNT_WIDTH'b0;
                                        dec_imm <= {{15{fet_inst[12]}}, fet_inst[6 : 2], 12'b0};
                                    end
                                end
                                3'b100: begin
                                    case (fet_inst[11 : 10])
                                        2'b00: begin  // C.SRLI
                                            dec_op  <= `SRLI;
                                            dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                                            dec_imm <= {26'b0, fet_inst[12 : 12], fet_inst[6 : 2]};
                                        end
                                        2'b01: begin  // C.SRAI
                                            dec_op  <= `SRAI;
                                            dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                                            dec_imm <= {26'b0, fet_inst[12 : 12], fet_inst[6 : 2]};
                                        end
                                        2'b10: begin  // C.ANDI
                                            dec_op  <= `ANDI;
                                            dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                                            dec_imm <= {{27{fet_inst[12]}}, fet_inst[6 : 2]};
                                        end
                                        2'b11: begin
                                            case (fet_inst[6 : 5])
                                                2'b00: begin  // C.SUB
                                                    dec_op  <= `SUB;
                                                    dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs2 <= {2'b01, fet_inst[4 : 2]};
                                                    dec_imm <= `XLEN'b0;
                                                end
                                                2'b01: begin  // C.XOR
                                                    dec_op  <= `XOR;
                                                    dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs2 <= {2'b01, fet_inst[4 : 2]};
                                                    dec_imm <= `XLEN'b0;
                                                end
                                                2'b10: begin  // C.OR
                                                    dec_op  <= `OR;
                                                    dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs2 <= {2'b01, fet_inst[4 : 2]};
                                                    dec_imm <= `XLEN'b0;
                                                end
                                                2'b11: begin  // C.AND
                                                    dec_op  <= `AND;
                                                    dec_rd  <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                                    dec_rs2 <= {2'b01, fet_inst[4 : 2]};
                                                    dec_imm <= `XLEN'b0;
                                                end
                                            endcase
                                        end
                                    endcase
                                end
                                3'b101: begin  // C.J
                                    dec_op  <= `JAL;
                                    dec_rd  <= `REG_CNT_WIDTH'd0;  // x0
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {{21{fet_inst[12]}}, fet_inst[8 : 8], fet_inst[10 : 9], fet_inst[6 : 6], fet_inst[7 : 7], fet_inst[2 : 2], fet_inst[11 : 11], fet_inst[5 : 3], 1'b0};
                                end
                                3'b110: begin  // C.BEQZ
                                    dec_op  <= `BEQ;
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                    dec_rs2 <= `REG_CNT_WIDTH'd0;  // x0
                                    dec_imm <= {{24{fet_inst[12]}}, fet_inst[6 : 5], fet_inst[2 : 2], fet_inst[11 : 10], fet_inst[4 : 3], 1'b0};
                                end
                                3'b111: begin  // C.BNEZ
                                    dec_op  <= `BNE;
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= {2'b01, fet_inst[9 : 7]};
                                    dec_rs2 <= `REG_CNT_WIDTH'd0;  // x0
                                    dec_imm <= {{24{fet_inst[12]}}, fet_inst[6 : 5], fet_inst[2 : 2], fet_inst[11 : 10], fet_inst[4 : 3], 1'b0};
                                end
                            endcase
                        end
                        2'b10: begin
                            case (fet_inst[15 : 14])
                                2'b00: begin  // C.SLLI
                                    dec_op  <= `SLLI;
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= fet_inst[11 : 7];
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {26'b0, fet_inst[12 : 12], fet_inst[6 : 2]};
                                end
                                2'b01: begin  // C.LWSP
                                    dec_op  <= `LW;
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= `REG_CNT_WIDTH'd2;  // sp
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {24'b0, fet_inst[3 : 2], fet_inst[12 : 12], fet_inst[6 : 4], 2'b0};
                                end
                                2'b10: begin
                                    if (fet_inst[12]) begin
                                        if (fet_inst[6 : 2] == `REG_CNT_WIDTH'b0) begin  // C.JALR
                                            dec_op  <= `JALR;
                                            dec_rd  <= `REG_CNT_WIDTH'd1;  // ra
                                            dec_rs1 <= fet_inst[11 : 7];
                                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                                            dec_imm <= `XLEN'b0;
                                        end else begin  // C.ADD
                                            dec_op  <= `ADD;
                                            dec_rd  <= fet_inst[11 : 7];
                                            dec_rs1 <= fet_inst[11 : 7];
                                            dec_rs2 <= fet_inst[6 : 2];
                                            dec_imm <= `XLEN'b0;
                                        end
                                    end else begin
                                        if (fet_inst[6 : 2] != `REG_CNT_WIDTH'b0) begin  // C.MV
                                            dec_op  <= `ADD;
                                            dec_rd  <= fet_inst[11 : 7];
                                            dec_rs1 <= `REG_CNT_WIDTH'd0;  // x0
                                            dec_rs2 <= fet_inst[6 : 2];
                                            dec_imm <= `XLEN'b0;
                                        end else begin  // C.JR
                                            dec_op  <= `JALR;
                                            dec_rd  <= `REG_CNT_WIDTH'd0;  // x0
                                            dec_rs1 <= fet_inst[11 : 7];
                                            dec_rs2 <= `REG_CNT_WIDTH'b0;
                                            dec_imm <= `XLEN'b0;
                                        end
                                    end
                                end
                                2'b11: begin  // C.SWSP
                                    dec_op  <= `SW;
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= `REG_CNT_WIDTH'd2;  // sp
                                    dec_rs2 <= fet_inst[6 : 2];
                                    dec_imm <= {24'b0, fet_inst[8 : 7], fet_inst[12 : 9], 2'b0};
                                end
                            endcase
                        end
                        2'b11: begin
                            case (fet_inst[6 : 0])
                                7'b0110111, 7'b0010111: begin  // U type
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {fet_inst[31 : 12], 12'b0};
                                end
                                7'b1101111: begin  // J type
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= {{13{fet_inst[31]}}, fet_inst[19 : 12], fet_inst[20 : 20], fet_inst[30 : 25], fet_inst[24 : 21]};
                                end
                                7'b1100011: begin  // B type
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= fet_inst[19 : 15];
                                    dec_rs2 <= fet_inst[24 : 20];
                                    dec_imm <= {{21{fet_inst[31]}}, fet_inst[7 : 7], fet_inst[30 : 25], fet_inst[11 : 8], 1'b0};
                                end
                                7'b0100011: begin  // S type
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= fet_inst[19 : 15];
                                    dec_rs2 <= fet_inst[24 : 20];
                                    dec_imm <= {{21{fet_inst[31]}}, fet_inst[30 : 25], fet_inst[11 : 7]};
                                end
                                7'b0110011: begin  // R type
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= fet_inst[19 : 15];
                                    dec_rs2 <= fet_inst[24 : 20];
                                    dec_imm <= `XLEN'b0;
                                end
                                7'b1100111, 7'b0010011, 7'b0000011: begin  // I type
                                    dec_rd  <= fet_inst[11 : 7];
                                    dec_rs1 <= fet_inst[19 : 15];
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= ((fet_inst[6 : 0] == 7'b0010011 && fet_inst[13 : 12] == 2'b01) ? {27'b0, fet_inst[24 : 20]} : {{21{fet_inst[31]}}, fet_inst[30 : 20]});
                                end
                                default: begin
                                    dec_rd  <= `REG_CNT_WIDTH'b0;
                                    dec_rs1 <= `REG_CNT_WIDTH'b0;
                                    dec_rs2 <= `REG_CNT_WIDTH'b0;
                                    dec_imm <= `XLEN'b0;
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
                    endcase
                end
            end
        end
    end
endmodule
