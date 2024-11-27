`include "global_params.v"

module fetcher (
    // input
    input wire                 clk,
    input wire                 flush,
    input wire [`XLEN - 1 : 0] correct_pc,
    input wire                 stall,

    // from Branch Predictor
    input wire bp_pred,

    // from Icache
    input wire                 icache_ready,
    input wire [`XLEN - 1 : 0] icache_inst,

    // output
    output reg                 fet_ready,         // to Decoder
    output reg [`XLEN - 1 : 0] fet_inst,          // to Decoder
    output reg [`XLEN - 1 : 0] fet_inst_addr,     // to Decoder
    output reg                 fet_jump_pred,     // to Decoder
    output reg [`XLEN - 1 : 0] fet_pc,            // to Icache
    output reg                 fet_icache_enable  // to Icache
);
    initial begin
        fet_ready         = 1'b0;
        fet_inst          = `XLEN'b0;
        fet_inst_addr     = `XLEN'b0;
        fet_jump_pred     = 1'b0;
        fet_pc            = `XLEN'b0;
        fet_icache_enable = 1'b1;
    end

    always @(posedge clk) begin
        if (flush) begin
            fet_ready         <= 1'b0;
            fet_pc            <= correct_pc;
            fet_icache_enable <= 1'b1;
        end else begin
            if (!stall && icache_ready) begin
                fet_ready         <= 1'b1;
                fet_inst          <= icache_inst;
                fet_inst_addr     <= fet_pc;
                fet_jump_pred     <= bp_pred;
                fet_icache_enable <= 1'b1;
                if (icache_inst[1 : 0] == 2'b11) begin
                    if (icache_inst[6 : 0] == 7'b1101111) begin  // JAL
                        fet_pc <= fet_pc + {{12{icache_inst[31]}}, icache_inst[19 : 12], icache_inst[20 : 20], icache_inst[30 : 25], icache_inst[24 : 21], 1'b0};
                    end else if (icache_inst[6 : 0] == 7'b1100011 && bp_pred) begin  // Branch instruction
                        fet_pc <= fet_pc + {{20{icache_inst[31]}}, icache_inst[7 : 7], icache_inst[30 : 25], icache_inst[11 : 8], 1'b0};
                    end else begin
                        fet_pc <= fet_pc + `XLEN'd4;
                    end
                end else begin  // C extension
                    if (icache_inst[1 : 0] == 2'b01 && icache_inst[14 : 13] == 2'b01) begin  // C.JAL and C.J
                        fet_pc <= fet_pc + {{21{icache_inst[12]}}, icache_inst[8 : 8], icache_inst[10 : 9], icache_inst[6 : 6], icache_inst[7 : 7], icache_inst[2 : 2], icache_inst[11 : 11], icache_inst[5 : 3], 1'b0};
                    end else if (icache_inst[1 : 0] == 2'b01 && icache_inst[15 : 14] == 2'b11) begin  // C.BEQZ and C.BNEZ
                        fet_pc <= fet_pc + {{24{icache_inst[12]}}, icache_inst[6 : 5], icache_inst[2 : 2], icache_inst[11 : 10], icache_inst[4 : 3], 1'b0};
                    end else begin
                        fet_pc <= fet_pc + `XLEN'd2;
                    end
                end
            end else begin
                fet_ready         <= 1'b0;
                fet_icache_enable <= 1'b0;
            end
        end
    end
endmodule
