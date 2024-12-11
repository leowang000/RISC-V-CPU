`include "global_params.v"

module icache (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,

    // from Fetcher
    input wire                 fet_icache_enable,
    input wire [`XLEN - 1 : 0] fet_pc,

    // from Memory Controller
    input wire                 mem_busy,
    input wire                 mem_inst_ready,
    input wire [`XLEN - 1 : 0] mem_inst,
    input wire [`XLEN - 1 : 0] mem_inst_addr,

    // output
    output wire                 icache_ready,       // to Fetcher
    output wire [`XLEN - 1 : 0] icache_inst,        // to Fetcher
    output reg                  icache_mem_enable,  // to Memory Controller
    output reg  [`XLEN - 1 : 0] icache_inst_addr    // to Memory Controller
);
    reg                  valid            [`ICACHE_LINE_CNT - 1 : 0];
    reg  [        5 : 0] tag              [`ICACHE_LINE_CNT - 1 : 0];
    reg  [       15 : 0] data             [`ICACHE_LINE_CNT - 1 : 0];

    wire                 tmp_hit_16;
    wire                 tmp_hit_32;
    wire                 tmp_c_extension;
    wire [`XLEN - 1 : 0] tmp_addr;
    wire                 tmp_icache_ready;
    reg                  tmp_mem_enable;
    reg  [`XLEN - 1 : 0] tmp_inst_addr;

    assign tmp_hit_16       = fet_icache_enable && valid[fet_pc[10 : 1]] && tag[fet_pc[10 : 1]] == fet_pc[16 : 11];
    assign tmp_hit_32       = tmp_hit_16 && valid[fet_pc[10 : 1]+10'b1] && tag[fet_pc[10 : 1]+10'b1] == fet_pc[16 : 11] + `XLEN'b1;
    assign tmp_c_extension  = (data[fet_pc[10 : 1]][1 : 0] != 2'b11);
    assign tmp_addr         = mem_inst_addr + `XLEN'd2;
    assign tmp_icache_ready = ((tmp_hit_16 && tmp_c_extension) || (tmp_hit_32 && !tmp_c_extension));
    assign icache_ready     = tmp_icache_ready;
    assign icache_inst      = (tmp_hit_16 && tmp_c_extension ? {16'b0, data[fet_pc[10 : 1]]} : (tmp_hit_32 && !tmp_c_extension ? {data[fet_pc[10 : 1]+10'b1], data[fet_pc[10 : 1]]} : 32'b0));

    initial begin
        icache_mem_enable = 1'b0;
        icache_inst_addr  = `XLEN'b0;
        for (integer i = 0; i < `ICACHE_LINE_CNT; i = i + 1) begin
            valid[i] = 1'b0;
            tag[i]   = 6'b0;
            data[i]  = 16'b0;
        end
        tmp_mem_enable = 1'b0;
        tmp_inst_addr  = `XLEN'b0;
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst) begin
                icache_mem_enable <= 1'b0;
                icache_inst_addr  <= `XLEN'b0;
                for (integer i = 0; i < `ICACHE_LINE_CNT; i = i + 1) begin
                    valid[i] <= 1'b0;
                    tag[i]   <= 6'b0;
                    data[i]  <= 16'b0;
                end
                tmp_mem_enable <= 1'b0;
                tmp_inst_addr  <= `XLEN'b0;
            end else if (flush) begin
                icache_mem_enable <= 1'b0;
            end else if (!stall) begin
                if (mem_inst_ready) begin
                    valid[mem_inst_addr[10 : 1]] <= 1'b1;
                    tag[mem_inst_addr[10 : 1]]   <= mem_inst_addr[16 : 11];
                    data[mem_inst_addr[10 : 1]]  <= mem_inst[15 : 0];
                    if (mem_inst[1 : 0] == 2'b11) begin
                        valid[mem_inst_addr[10 : 1]+10'b1] <= 1'b1;
                        tag[mem_inst_addr[10 : 1]+10'b1]   <= tmp_addr[16 : 11];
                        data[mem_inst_addr[10 : 1]+10'b1]  <= mem_inst[31 : 16];
                    end
                end
                if (fet_icache_enable && !tmp_icache_ready) begin
                    if (mem_busy) begin
                        tmp_mem_enable <= 1'b1;
                        tmp_inst_addr  <= fet_pc;
                    end else begin
                        icache_mem_enable <= 1'b1;
                        icache_inst_addr  <= fet_pc;
                    end
                end
                if (!mem_busy && tmp_mem_enable) begin
                    icache_mem_enable <= 1'b1;
                    icache_inst_addr  <= tmp_inst_addr;
                    tmp_mem_enable    <= 1'b0;
                    tmp_inst_addr     <= `XLEN'b0;
                end
                if (icache_mem_enable) begin
                    icache_mem_enable <= 1'b0;
                end
            end
        end
    end
endmodule
