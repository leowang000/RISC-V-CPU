`include "global_params.v"

module fetcher (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,

    // from Branch Predictor
    input wire bp_pred,

    // from Icache
    input wire                 icache_ready,
    input wire [`XLEN - 1 : 0] icache_inst,

    // from Memory Controller
    input wire                 mem_fet_busy,
    input wire                 mem_inst_ready,
    input wire [`XLEN - 1 : 0] mem_inst,

    // from ROB
    input wire [`XLEN - 1 : 0] rob_correct_pc,

    // output
    output wire                 fet_mem_enable,     // to Memory Controller
    output reg                  fet_ready,          // to Decoder
    output reg  [`XLEN - 1 : 0] fet_inst,           // to Decoder
    output reg  [`XLEN - 1 : 0] fet_inst_addr,      // to Decoder
    output reg                  fet_jump_pred,      // to Decoder
    output reg                  fet_icache_enable,  // to Icache
    output reg  [`XLEN - 1 : 0] fet_pc              // to Icache
);
    wire [`XLEN - 1 : 0] tmp_inst;
    reg                  tmp_work;
    reg                  tmp_delay_mem_enable;

    assign fet_mem_enable = (((fet_icache_enable && !icache_ready) || tmp_delay_mem_enable) && !mem_fet_busy);
    assign tmp_inst       = (icache_ready ? icache_inst : mem_inst);

    initial begin
        fet_ready            = 1'b0;
        fet_inst             = `XLEN'b0;
        fet_inst_addr        = `XLEN'b0;
        fet_jump_pred        = 1'b0;
        fet_icache_enable    = 1'b0;
        fet_pc               = `XLEN'b0;
        tmp_work             = 1'b0;
        tmp_delay_mem_enable = 1'b0;
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst == 1'b1) begin  // in the first cycle after the cpu starts working, rst == 1'bx
                fet_ready            <= 1'b0;
                fet_inst             <= `XLEN'b0;
                fet_inst_addr        <= `XLEN'b0;
                fet_jump_pred        <= 1'b0;
                fet_icache_enable    <= 1'b0;
                fet_pc               <= `XLEN'b0;
                tmp_work             <= 1'b0;
                tmp_delay_mem_enable <= 1'b0;
            end else if (!tmp_work) begin
                fet_icache_enable <= 1'b1;
                tmp_work          <= 1'b1;
            end else if (flush) begin
                fet_ready            <= 1'b0;
                fet_pc               <= rob_correct_pc;
                fet_icache_enable    <= 1'b1;
                tmp_delay_mem_enable <= 1'b0;
            end else if (!stall) begin
                if (fet_icache_enable && !icache_ready && mem_fet_busy) begin
                    tmp_delay_mem_enable <= 1'b1;
                end
                if (!mem_fet_busy) begin
                    tmp_delay_mem_enable <= 1'b0;
                end
                if (icache_ready || mem_inst_ready) begin
                    fet_ready         <= 1'b1;
                    fet_inst          <= tmp_inst;
                    fet_inst_addr     <= fet_pc;
                    fet_jump_pred     <= bp_pred;
                    fet_icache_enable <= 1'b1;
                    if (tmp_inst[1 : 0] == 2'b11) begin
                        if (tmp_inst[6 : 0] == 7'b1101111) begin  // JAL
                            fet_pc <= fet_pc + {{12{tmp_inst[31]}}, tmp_inst[19 : 12], tmp_inst[20 : 20], tmp_inst[30 : 25], tmp_inst[24 : 21], 1'b0};
                        end else if (tmp_inst[6 : 0] == 7'b1100011 && bp_pred) begin  // Branch instruction
                            fet_pc <= fet_pc + {{20{tmp_inst[31]}}, tmp_inst[7 : 7], tmp_inst[30 : 25], tmp_inst[11 : 8], 1'b0};
                        end else begin
                            fet_pc <= fet_pc + `XLEN'd4;
                        end
                    end else begin  // C extension
                        if (tmp_inst[1 : 0] == 2'b01 && tmp_inst[14 : 13] == 2'b01) begin  // C.JAL and C.J
                            fet_pc <= fet_pc + {{21{tmp_inst[12]}}, tmp_inst[8 : 8], tmp_inst[10 : 9], tmp_inst[6 : 6], tmp_inst[7 : 7], tmp_inst[2 : 2], tmp_inst[11 : 11], tmp_inst[5 : 3], 1'b0};
                        end else if (tmp_inst[1 : 0] == 2'b01 && tmp_inst[15 : 14] == 2'b11) begin  // C.BEQZ and C.BNEZ
                            fet_pc <= fet_pc + {{24{tmp_inst[12]}}, tmp_inst[6 : 5], tmp_inst[2 : 2], tmp_inst[11 : 10], tmp_inst[4 : 3], 1'b0};
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
    end
endmodule
