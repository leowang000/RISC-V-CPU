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
    input wire                 mem_inst_ready,
    input wire [`XLEN - 1 : 0] mem_inst,
    input wire [`XLEN - 1 : 0] mem_inst_addr,

    // output
    output wire                 icache_ready,  // to Fetcher
    output wire [`XLEN - 1 : 0] icache_inst    // to Fetcher
);
    integer                    i;

    reg                        valid             [`ICACHE_SET_CNT - 1 : 0];
    reg     [`TAG_LEN - 1 : 0] tag               [`ICACHE_SET_CNT - 1 : 0];
    reg     [          15 : 0] data              [`ICACHE_SET_CNT - 1 : 0];

    wire                       tmp_hit_16;
    wire    [   `XLEN - 1 : 0] tmp_fet_pc;
    wire                       tmp_hit_32;
    wire                       tmp_c_extension;
    wire                       tmp_hit_ic;
    wire                       tmp_hit_i;
    wire    [   `XLEN - 1 : 0] tmp_mem_inst_addr;

    assign tmp_hit_16        = ((fet_icache_enable && valid[fet_pc[`ICACHE_INDEX_RANGE]]) && tag[fet_pc[`ICACHE_INDEX_RANGE]] == fet_pc[`ICACHE_TAG_RANGE]);
    assign tmp_fet_pc        = fet_pc + `XLEN'd2;
    assign tmp_hit_32        = (tmp_hit_16 && (valid[tmp_fet_pc[`ICACHE_INDEX_RANGE]] && tag[tmp_fet_pc[`ICACHE_INDEX_RANGE]] == tmp_fet_pc[`ICACHE_TAG_RANGE]));
    assign tmp_c_extension   = (data[fet_pc[`ICACHE_INDEX_RANGE]][1 : 0] != 2'b11);
    assign tmp_hit_ic        = tmp_hit_16 && tmp_c_extension;
    assign tmp_hit_i         = tmp_hit_32 && !tmp_c_extension;
    assign tmp_mem_inst_addr = mem_inst_addr + `XLEN'd2;
    assign icache_ready      = (tmp_hit_ic || tmp_hit_i);
    assign icache_inst       = (tmp_hit_ic ? {16'b0, data[fet_pc[`ICACHE_INDEX_RANGE]]} : (tmp_hit_i ? {data[tmp_fet_pc[`ICACHE_INDEX_RANGE]], data[fet_pc[`ICACHE_INDEX_RANGE]]} : 32'b0));

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `ICACHE_SET_CNT; i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i]   <= `TAG_LEN'b0;
                data[i]  <= 16'b0;
            end
        end else if (rdy && !flush && !stall) begin
            if (mem_inst_ready) begin
                valid[mem_inst_addr[`ICACHE_INDEX_RANGE]] <= 1'b1;
                tag[mem_inst_addr[`ICACHE_INDEX_RANGE]]   <= mem_inst_addr[`ICACHE_TAG_RANGE];
                data[mem_inst_addr[`ICACHE_INDEX_RANGE]]  <= mem_inst[15 : 0];
                if (mem_inst[1 : 0] == 2'b11) begin
                    valid[tmp_mem_inst_addr[`ICACHE_INDEX_RANGE]] <= 1'b1;
                    tag[tmp_mem_inst_addr[`ICACHE_INDEX_RANGE]]   <= tmp_mem_inst_addr[`ICACHE_TAG_RANGE];
                    data[tmp_mem_inst_addr[`ICACHE_INDEX_RANGE]]  <= mem_inst[31 : 16];
                end
            end
        end
    end
endmodule
