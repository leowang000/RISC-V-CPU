`include "global_params.v"

module memory_controller (
    // input
    input wire clk,
    input wire flush,
    input wire stall,

    // from Icache
    input wire                 icache_mem_enable,
    input wire [`XLEN - 1 : 0] icache_inst_addr,

    // from LSB
    input wire                           lsb_ready,
    input wire [ `INST_OP_WIDTH - 1 : 0] lsb_op,
    input wire [          `XLEN - 1 : 0] lsb_addr,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] lsb_id,

    // from RAM
    input wire [7:0] ram_data,

    // from ROB
    input wire                          rob_store_enable,
    input wire [`INST_OP_WIDTH - 1 : 0] rob_store_op,
    input wire [         `XLEN - 1 : 0] rob_store_addr,
    input wire [         `XLEN - 1 : 0] rob_store_val,

    // output
    output wire [                    7:0] mem_ram_data,    // to RAM
    output wire [          `XLEN - 1 : 0] mem_ram_addr,    // to RAM
    output wire                           mem_ram_wr       // to RAM
    output reg                            mem_busy,
    output reg                            mem_inst_ready,  // inst output
    output reg  [          `XLEN - 1 : 0] mem_inst,        // inst output
    output reg  [          `XLEN - 1 : 0] mem_inst_addr,   // inst output
    output reg                            mem_data_ready,  // load output
    output reg  [          `XLEN - 1 : 0] mem_data,        // load output
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] mem_id,          // load output
);
    localparam STATE_WORD = 2'b11;
    localparam STATE_HALF = 2'b01;
    localparam STATE_BYTE = 2'b00;

    reg                           tmp_load_inst;
    reg [          `XLEN - 1 : 0] tmp_inst_addr;
    reg                           tmp_load_data;
    reg                           tmp_store_data;
    reg [ `INST_OP_WIDTH - 1 : 0] tmp_op;
    reg [          `XLEN - 1 : 0] tmp_addr;
    reg [          `XLEN - 1 : 0] tmp_val;
    reg [`ROB_SIZE_WIDTH - 1 : 0] tmp_id;
    reg [                  1 : 0] tmp_state;

    initial begin

    end

    always @(*) begin
        if (icache_mem_enable) begin
            tmp_load_inst = 1'b1;
            tmp_inst_addr = icache_inst_addr;
        end
    end

    always @(*) begin
        if (lsb_ready) begin
            tmp_load_data = 1'b1;
            tmp_op        = lsb_op;
            tmp_addr      = lsb_addr;
            tmp_val       = `XLEN'b0;
            tmp_id        = lsb_id;
            tmp_state     = (lsb_op == `LW ? STATE_WORD : (lsb_op == `LH || lsb_op == `LHU ? STATE_HALF : STATE_BYTE));
        end
    end

    always @(*) begin
        if (rob_mem_enable) begin
            tmp_store_data = 1'b1;
            tmp_op         = rob_mem_op;
            tmp_addr       = rob_mem_addr;
            tmp_val        = rob_mem_val;
            tmp_id         = `ROB_SIZE_WIDTH'b0;
            tmp_state      = (rob_mem_op == `SW ? STATE_WORD : (rob_mem_op == `SH ? STATE_HALF : STATE_BYTE));
        end
    end

    always @(posedge clk) begin
        if (flush) begin
            mem_busy       = 1'b0;
            mem_inst_ready = 1'b0;
            mem_data_ready = 1'b0;
            tmp_load_inst  = 1'b0;
            tmp_load_data  = 1'b0;
            tmp_store_data = 1'b0;
        end else begin
            
        end
    end
endmodule
