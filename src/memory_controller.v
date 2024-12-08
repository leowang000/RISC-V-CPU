`include "global_params.v"

module memory_controller (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,

    // from Icache
    input wire                 icache_mem_enable,
    input wire [`XLEN - 1 : 0] icache_inst_addr,

    // from LSB
    input wire                           lsb_mem_enable,
    input wire [ `INST_OP_WIDTH - 1 : 0] lsb_mem_op,
    input wire [          `XLEN - 1 : 0] lsb_mem_addr,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] lsb_mem_id,

    // from RAM
    input wire [7 : 0] ram_data,

    // from ROB
    input wire                          rob_mem_enable,
    input wire [`INST_OP_WIDTH - 1 : 0] rob_mem_op,
    input wire [         `XLEN - 1 : 0] rob_mem_addr,
    input wire [         `XLEN - 1 : 0] rob_mem_val,

    // output
    output reg                           mem_busy,
    output reg                           mem_inst_ready,  // inst output
    output reg [          `XLEN - 1 : 0] mem_inst,        // inst output
    output reg [          `XLEN - 1 : 0] mem_inst_addr,   // inst output
    output reg                           mem_data_ready,  // load output
    output reg [          `XLEN - 1 : 0] mem_data,        // load output
    output reg [`ROB_SIZE_WIDTH - 1 : 0] mem_id,          // load output
    output reg [                  7 : 0] mem_ram_data,    // to RAM
    output reg [          `XLEN - 1 : 0] mem_ram_addr,    // to RAM
    output reg                           mem_ram_wr       // to RAM
);
    localparam STATE_WORD = 3'b100;
    localparam STATE_HALF = 3'b010;
    localparam STATE_BYTE = 3'b001;

    reg                           tmp_load_inst;
    reg [          `XLEN - 1 : 0] tmp_inst_addr;
    reg                           tmp_load_data;
    reg                           tmp_store_data;
    reg [          `XLEN - 1 : 0] tmp_addr;
    reg [          `XLEN - 1 : 0] tmp_val;
    reg [`ROB_SIZE_WIDTH - 1 : 0] tmp_id;
    reg [                  2 : 0] tmp_state;
    reg [                  2 : 0] tmp_offset;
    reg [          `XLEN - 1 : 0] tmp_load_res;

    initial begin
        mem_busy       = 1'b0;
        mem_inst_ready = 1'b0;
        mem_inst       = `XLEN'b0;
        mem_inst_addr  = `XLEN'b0;
        mem_data_ready = 1'b0;
        mem_data       = `XLEN'b0;
        mem_id         = `ROB_SIZE_WIDTH'b0;
        mem_ram_data   = 8'b0;
        mem_ram_addr   = `XLEN'b0;
        mem_ram_wr     = 1'b0;
        tmp_load_inst  = 1'b0;
        tmp_inst_addr  = `XLEN'b0;
        tmp_load_data  = 1'b0;
        tmp_store_data = 1'b0;
        tmp_addr       = `XLEN'b0;
        tmp_val        = `XLEN'b0;
        tmp_id         = `ROB_SIZE_WIDTH'b0;
        tmp_state      = 3'b0;
        tmp_offset     = 3'b0;
        tmp_load_res   = `XLEN'b0;
    end

    always @(*) begin
        if (rdy) begin
            if (rst) begin
                mem_busy       = 1'b0;
                mem_inst_ready = 1'b0;
                mem_inst       = `XLEN'b0;
                mem_inst_addr  = `XLEN'b0;
                mem_data_ready = 1'b0;
                mem_data       = `XLEN'b0;
                mem_id         = `ROB_SIZE_WIDTH'b0;
                mem_ram_data   = 8'b0;
                mem_ram_addr   = `XLEN'b0;
                mem_ram_wr     = 1'b0;
                tmp_load_inst  = 1'b0;
                tmp_inst_addr  = `XLEN'b0;
                tmp_load_data  = 1'b0;
                tmp_store_data = 1'b0;
                tmp_addr       = `XLEN'b0;
                tmp_val        = `XLEN'b0;
                tmp_id         = `ROB_SIZE_WIDTH'b0;
                tmp_state      = 3'b0;
                tmp_offset     = 3'b0;
                tmp_load_res   = `XLEN'b0;
            end else if (flush) begin
                mem_busy       = 1'b0;
                mem_inst_ready = 1'b0;
                mem_data_ready = 1'b0;
                mem_ram_data   = 8'b0;
                mem_ram_addr   = `XLEN'b0;
                mem_ram_wr     = 1'b0;
                tmp_load_inst  = 1'b0;
                tmp_load_data  = 1'b0;
                tmp_store_data = 1'b0;
            end else if (!stall) begin
                if (icache_mem_enable) begin
                    mem_busy      = 1'b1;
                    tmp_load_inst = 1'b1;
                    tmp_inst_addr = icache_inst_addr;
                    tmp_offset    = 3'd0;
                end
                if (lsb_mem_enable) begin
                    mem_busy      = 1'b1;
                    tmp_load_data = 1'b1;
                    tmp_addr      = lsb_mem_addr;
                    tmp_val       = `XLEN'b0;
                    tmp_id        = lsb_mem_id;
                    tmp_state     = (lsb_mem_op == `LW ? STATE_WORD : (lsb_mem_op == `LH || lsb_mem_op == `LHU ? STATE_HALF : STATE_BYTE));
                    tmp_offset    = 3'd0;
                end
                if (rob_mem_enable) begin
                    mem_busy       = 1'b1;
                    tmp_store_data = 1'b1;
                    tmp_addr       = rob_mem_addr;
                    tmp_val        = rob_mem_val;
                    tmp_id         = `ROB_SIZE_WIDTH'b0;
                    tmp_state      = (rob_mem_op == `SW ? STATE_WORD : (rob_mem_op == `SH ? STATE_HALF : STATE_BYTE));
                    tmp_offset     = 3'd0;
                end
                if ((tmp_load_data || tmp_load_inst) && tmp_offset != 3'd0) begin
                    tmp_load_res[tmp_offset*8-1-:8] = ram_data;
                end
                if (!tmp_load_data && !tmp_store_data && tmp_load_inst && ((tmp_offset == 3'd2 && tmp_load_res[1 : 0] != 2'b11) || (tmp_offset == 3'd4 && tmp_load_res[1 : 0] == 2'b11))) begin
                    mem_inst_ready = 1'b1;
                    mem_inst       = tmp_load_res;
                    mem_inst_addr  = tmp_inst_addr;
                    mem_busy       = 1'b0;
                    tmp_load_inst  = 1'b0;
                end else begin
                    mem_inst_ready = 1'b0;
                    mem_inst       = `XLEN'b0;
                    mem_inst_addr  = `XLEN'b0;
                end
                if (tmp_load_data && tmp_offset == tmp_state) begin
                    mem_data_ready = 1'b1;
                    mem_data       = tmp_load_res;
                    mem_id         = tmp_id;
                    mem_busy       = tmp_load_inst;
                    tmp_load_data  = 1'b0;
                    tmp_offset     = 3'd0;
                end else begin
                    mem_data_ready = 1'b0;
                    mem_data       = `XLEN'b0;
                    mem_id         = `ROB_SIZE_WIDTH'b0;
                end
                if (tmp_store_data && tmp_offset == tmp_state) begin
                    mem_busy       = tmp_load_inst;
                    tmp_store_data = 1'b0;
                    tmp_offset     = 3'd0;
                end
                if (tmp_load_data) begin
                    mem_ram_data = 8'b0;
                    mem_ram_addr = tmp_addr + tmp_offset;
                    mem_ram_wr   = 1'b0;
                    tmp_offset   = tmp_offset + 3'd1;
                end else if (tmp_store_data) begin
                    mem_ram_data = tmp_val[8*tmp_offset+7-:8];
                    mem_ram_addr = tmp_addr + tmp_offset;
                    mem_ram_wr   = 1'b1;
                    tmp_offset   = tmp_offset + 3'd1;
                end else if (tmp_load_inst) begin
                    mem_ram_data = 8'b0;
                    mem_ram_addr = tmp_inst_addr + tmp_offset;
                    mem_ram_wr   = 1'b0;
                    tmp_offset   = tmp_offset + 3'd1;
                end else begin
                    mem_ram_data = 8'b0;
                    mem_ram_addr = `XLEN'b0;
                    mem_ram_wr   = 1'b0;
                end
            end
        end
    end
endmodule
