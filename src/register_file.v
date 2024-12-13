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

    // debug begin
    wire [`XLEN - 1 : 0] V_X00_zero;
    wire [`XLEN - 1 : 0] V_X01_ra;
    wire [`XLEN - 1 : 0] V_X02_sp;
    wire [`XLEN - 1 : 0] V_X03_gp;
    wire [`XLEN - 1 : 0] V_X04_tp;
    wire [`XLEN - 1 : 0] V_X05_t0;
    wire [`XLEN - 1 : 0] V_X06_t1;
    wire [`XLEN - 1 : 0] V_X07_t2;
    wire [`XLEN - 1 : 0] V_X08_s0;
    wire [`XLEN - 1 : 0] V_X09_s1;
    wire [`XLEN - 1 : 0] V_X10_a0;
    wire [`XLEN - 1 : 0] V_X11_a1;
    wire [`XLEN - 1 : 0] V_X12_a2;
    wire [`XLEN - 1 : 0] V_X13_a3;
    wire [`XLEN - 1 : 0] V_X14_a4;
    wire [`XLEN - 1 : 0] V_X15_a5;
    wire [`XLEN - 1 : 0] V_X16_a6;
    wire [`XLEN - 1 : 0] V_X17_a7;
    wire [`XLEN - 1 : 0] V_X18_s2;
    wire [`XLEN - 1 : 0] V_X19_s3;
    wire [`XLEN - 1 : 0] V_X20_s4;
    wire [`XLEN - 1 : 0] V_X21_s5;
    wire [`XLEN - 1 : 0] V_X22_s6;
    wire [`XLEN - 1 : 0] V_X23_s7;
    wire [`XLEN - 1 : 0] V_X24_s8;
    wire [`XLEN - 1 : 0] V_X25_s9;
    wire [`XLEN - 1 : 0] V_X26_s10;
    wire [`XLEN - 1 : 0] V_X27_s11;
    wire [`XLEN - 1 : 0] V_X28_t3;
    wire [`XLEN - 1 : 0] V_X29_t4;
    wire [`XLEN - 1 : 0] V_X30_t5;
    wire [`XLEN - 1 : 0] V_X31_t6;

    assign V_X00_zero = val[0];
    assign V_X01_ra   = val[1];
    assign V_X02_sp   = val[2];
    assign V_X03_gp   = val[3];
    assign V_X04_tp   = val[4];
    assign V_X05_t0   = val[5];
    assign V_X06_t1   = val[6];
    assign V_X07_t2   = val[7];
    assign V_X08_s0   = val[8];
    assign V_X09_s1   = val[9];
    assign V_X10_a0   = val[10];
    assign V_X11_a1   = val[11];
    assign V_X12_a2   = val[12];
    assign V_X13_a3   = val[13];
    assign V_X14_a4   = val[14];
    assign V_X15_a5   = val[15];
    assign V_X16_a6   = val[16];
    assign V_X17_a7   = val[17];
    assign V_X18_s2   = val[18];
    assign V_X19_s3   = val[19];
    assign V_X20_s4   = val[20];
    assign V_X21_s5   = val[21];
    assign V_X22_s6   = val[22];
    assign V_X23_s7   = val[23];
    assign V_X24_s8   = val[24];
    assign V_X25_s9   = val[25];
    assign V_X26_s10  = val[26];
    assign V_X27_s11  = val[27];
    assign V_X28_t3   = val[28];
    assign V_X29_t4   = val[29];
    assign V_X30_t5   = val[30];
    assign V_X31_t6   = val[31];

    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X00_zero;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X01_ra;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X02_sp;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X03_gp;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X04_tp;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X05_t0;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X06_t1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X07_t2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X08_s0;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X09_s1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X10_a0;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X11_a1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X12_a2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X13_a3;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X14_a4;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X15_a5;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X16_a6;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X17_a7;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X18_s2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X19_s3;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X20_s4;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X21_s5;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X22_s6;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X23_s7;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X24_s8;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X25_s9;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X26_s10;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X27_s11;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X28_t3;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X29_t4;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X30_t5;
    wire [`DEPENDENCY_WIDTH - 1 : 0] Q_X31_t6;

    assign Q_X00_zero = dep[0];
    assign Q_X01_ra   = dep[1];
    assign Q_X02_sp   = dep[2];
    assign Q_X03_gp   = dep[3];
    assign Q_X04_tp   = dep[4];
    assign Q_X05_t0   = dep[5];
    assign Q_X06_t1   = dep[6];
    assign Q_X07_t2   = dep[7];
    assign Q_X08_s0   = dep[8];
    assign Q_X09_s1   = dep[9];
    assign Q_X10_a0   = dep[10];
    assign Q_X11_a1   = dep[11];
    assign Q_X12_a2   = dep[12];
    assign Q_X13_a3   = dep[13];
    assign Q_X14_a4   = dep[14];
    assign Q_X15_a5   = dep[15];
    assign Q_X16_a6   = dep[16];
    assign Q_X17_a7   = dep[17];
    assign Q_X18_s2   = dep[18];
    assign Q_X19_s3   = dep[19];
    assign Q_X20_s4   = dep[20];
    assign Q_X21_s5   = dep[21];
    assign Q_X22_s6   = dep[22];
    assign Q_X23_s7   = dep[23];
    assign Q_X24_s8   = dep[24];
    assign Q_X25_s9   = dep[25];
    assign Q_X26_s10  = dep[26];
    assign Q_X27_s11  = dep[27];
    assign Q_X28_t3   = dep[28];
    assign Q_X29_t4   = dep[29];
    assign Q_X30_t5   = dep[30];
    assign Q_X31_t6   = dep[31];
    // debug end

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
