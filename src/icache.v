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
    output wire                 icache_ready,  // to Fetcher
    output wire [`XLEN - 1 : 0] icache_inst    // to Fetcher
);
    integer                 i;

    reg                     valid             [`ICACHE_SET_CNT - 1 : 0];
    reg     [        5 : 0] tag               [`ICACHE_SET_CNT - 1 : 0];
    reg     [       15 : 0] data              [`ICACHE_SET_CNT - 1 : 0];

    wire                    tmp_hit_16;
    wire    [`XLEN - 1 : 0] tmp_fet_pc;
    wire                    tmp_hit_32;
    wire                    tmp_c_extension;
    wire    [`XLEN - 1 : 0] tmp_mem_inst_addr;

    assign tmp_hit_16        = (fet_icache_enable && valid[fet_pc[10 : 1]] && tag[fet_pc[10 : 1]] == fet_pc[16 : 11]);
    assign tmp_fet_pc        = fet_pc + `XLEN'd2;
    assign tmp_hit_32        = (tmp_hit_16 && valid[tmp_fet_pc[10 : 1]] && tag[tmp_fet_pc[10 : 1]] == tmp_fet_pc[16 : 11]);
    assign tmp_c_extension   = (data[fet_pc[10 : 1]][1 : 0] != 2'b11);
    assign tmp_mem_inst_addr = mem_inst_addr + `XLEN'd2;
    assign icache_ready      = ((tmp_hit_16 && tmp_c_extension) || (tmp_hit_32 && !tmp_c_extension));
    assign icache_inst       = (tmp_hit_16 && tmp_c_extension ? {16'b0, data[fet_pc[10 : 1]]} : (tmp_hit_32 && !tmp_c_extension ? {data[tmp_fet_pc[10 : 1]], data[fet_pc[10 : 1]]} : 32'b0));

    initial begin
        for (i = 0; i < `ICACHE_SET_CNT; i = i + 1) begin
            valid[i] = 1'b0;
            tag[i]   = 6'b0;
            data[i]  = 16'b0;
        end
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst) begin
                for (i = 0; i < `ICACHE_SET_CNT; i = i + 1) begin
                    valid[i] <= 1'b0;
                    tag[i]   <= 6'b0;
                    data[i]  <= 16'b0;
                end
            end else if (!flush && !stall) begin
                if (mem_inst_ready) begin
                    valid[mem_inst_addr[10 : 1]] <= 1'b1;
                    tag[mem_inst_addr[10 : 1]]   <= mem_inst_addr[16 : 11];
                    data[mem_inst_addr[10 : 1]]  <= mem_inst[15 : 0];
                    if (mem_inst[1 : 0] == 2'b11) begin
                        valid[tmp_mem_inst_addr[10 : 1]] <= 1'b1;
                        tag[tmp_mem_inst_addr[10 : 1]]   <= tmp_mem_inst_addr[16 : 11];
                        data[tmp_mem_inst_addr[10 : 1]]  <= mem_inst[31 : 16];
                    end
                end
            end
        end
    end
endmodule
