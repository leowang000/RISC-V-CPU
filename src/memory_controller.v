`include "global_params.v"

module memory_controller (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire flush,
    input wire stall,
    input wire io_buffer_full,

    // from Fetcher
    input wire                 fet_mem_enable,
    input wire [`XLEN - 1 : 0] fet_pc,

    // from LSB
    input wire                           lsb_mem_enable,
    input wire [ `INST_OP_WIDTH - 1 : 0] lsb_mem_op,
    input wire [          `XLEN - 1 : 0] lsb_mem_addr,
    input wire [          `XLEN - 1 : 0] lsb_mem_data,
    input wire [`ROB_SIZE_WIDTH - 1 : 0] lsb_mem_id,

    // from RAM
    input wire [7 : 0] ram_data,

    // output
    output wire                           mem_busy,
    output wire                           mem_fet_busy,    // to Fetcher, avoiding wire dependency cycle
    output wire [          `XLEN - 1 : 0] mem_inst,        // inst output
    output wire [          `XLEN - 1 : 0] mem_data,        // load output
    output reg                            mem_inst_ready,  // inst output
    output reg  [          `XLEN - 1 : 0] mem_inst_addr,   // inst output
    output reg                            mem_data_ready,  // load output
    output reg  [`ROB_SIZE_WIDTH - 1 : 0] mem_id,          // load output
    output reg  [                  7 : 0] mem_ram_data,    // to RAM
    output reg  [          `XLEN - 1 : 0] mem_ram_addr,    // to RAM
    output reg                            mem_ram_wr       // to RAM
);
    localparam STATE_WORD = 2'b11;
    localparam STATE_HALF = 2'b01;
    localparam STATE_BYTE = 2'b00;

    wire                           tmp_io;
    wire                           tmp_lsb_load_enable;
    wire                           tmp_lsb_store_enable;
    wire                           tmp_mem_inst_ready;
    wire [          `XLEN - 1 : 0] tmp_cur_load_res;
    reg                            tmp_busy;
    reg  [          `XLEN - 1 : 0] tmp_mem_inst;
    reg                            tmp_load_inst;
    reg  [          `XLEN - 1 : 0] tmp_inst_addr;
    reg                            tmp_load_data;
    reg                            tmp_store_data;
    reg  [          `XLEN - 1 : 0] tmp_addr;
    reg  [          `XLEN - 1 : 0] tmp_data;
    reg  [`ROB_SIZE_WIDTH - 1 : 0] tmp_id;
    reg                            tmp_unsigned;
    reg  [                  1 : 0] tmp_state;
    reg  [                  1 : 0] tmp_offset;
    reg  [                 23 : 0] tmp_load_res;
    reg  [                  1 : 0] tmp_last_offset;
    reg                            tmp_last_mem_inst_ready;
    reg                            tmp_io_delay;

    assign tmp_io               = (lsb_mem_enable && (lsb_mem_addr == `XLEN'h30000 || lsb_mem_addr == `XLEN'h30004));
    assign tmp_lsb_store_enable = (lsb_mem_enable && (lsb_mem_op == `SB || lsb_mem_op == `SH || lsb_mem_op == `SW));
    assign tmp_lsb_load_enable  = (lsb_mem_enable && !tmp_lsb_store_enable);
    assign tmp_mem_inst_ready   = (!tmp_load_data && !tmp_store_data && (((tmp_offset == STATE_HALF && ram_data[1 : 0] != 2'b11) || (tmp_offset == STATE_WORD && tmp_load_res[1 : 0] == 2'b11))));
    assign tmp_cur_load_res     = (tmp_last_offset == STATE_BYTE ? {tmp_unsigned ? 24'b0 : {24{ram_data[7]}}, ram_data} : (tmp_last_offset == STATE_HALF ? {tmp_unsigned ? 16'b0 : {16{ram_data[7]}}, ram_data, tmp_load_res[7 : 0]} : {ram_data, tmp_load_res}));
    assign mem_busy             = (fet_mem_enable || lsb_mem_enable || tmp_busy);
    assign mem_fet_busy         = tmp_busy;
    assign mem_inst             = (mem_inst_ready ? tmp_mem_inst : `XLEN'b0);
    assign mem_data             = (mem_data_ready ? tmp_cur_load_res : `XLEN'b0);

    always @(*) begin
        if (tmp_last_mem_inst_ready) begin
            tmp_mem_inst = tmp_cur_load_res;
        end
    end

    always @(posedge clk) begin
        if (rdy) begin
            tmp_last_mem_inst_ready <= (rst ? 1'b0 : tmp_mem_inst_ready);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_inst_ready  <= 1'b0;
            mem_inst_addr   <= `XLEN'b0;
            mem_data_ready  <= 1'b0;
            mem_id          <= `ROB_SIZE_WIDTH'b0;
            mem_ram_data    <= 8'b0;
            mem_ram_addr    <= `XLEN'b0;
            mem_ram_wr      <= 1'b0;
            tmp_busy        <= 1'b0;
            tmp_load_inst   <= 1'b0;
            tmp_inst_addr   <= `XLEN'b0;
            tmp_load_data   <= 1'b0;
            tmp_store_data  <= 1'b0;
            tmp_addr        <= `XLEN'b0;
            tmp_data        <= `XLEN'b0;
            tmp_id          <= `ROB_SIZE_WIDTH'b0;
            tmp_unsigned    <= 1'b0;
            tmp_state       <= 2'b0;
            tmp_offset      <= 2'b0;
            tmp_load_res    <= 24'b0;
            tmp_last_offset <= 2'b0;
            tmp_io_delay    <= 1'b0;
        end else if (rdy) begin
            if (flush) begin  // only flush instruction load and data load
                tmp_load_inst  <= 1'b0;
                tmp_load_data  <= 1'b0;
                mem_inst_ready <= 1'b0;
                mem_data_ready <= 1'b0;
                if (!tmp_store_data && !tmp_lsb_store_enable) begin
                    mem_ram_data <= 8'b0;
                    mem_ram_addr <= `XLEN'b0;
                    mem_ram_wr   <= 1'b0;
                    tmp_busy     <= 1'b0;
                    tmp_offset   <= 2'b0;
                end
            end
            if (!tmp_io_delay) begin
                if (!flush) begin
                    mem_data_ready <= (tmp_load_data && tmp_offset == tmp_state && !(tmp_io && io_buffer_full));
                    if (tmp_mem_inst_ready) begin
                        mem_inst_ready <= 1'b1;
                    end else if (!stall) begin
                        mem_inst_ready <= 1'b0;
                    end
                end
                if (!tmp_load_inst && !tmp_load_data && !tmp_store_data) begin
                    if ((!flush && (fet_mem_enable || tmp_lsb_load_enable)) || tmp_lsb_store_enable) begin
                        tmp_busy     <= 1'b1;
                        tmp_offset   <= 2'd0;
                        tmp_load_res <= 24'b0;
                    end
                    if (!flush && fet_mem_enable) begin
                        tmp_load_inst <= 1'b1;
                        tmp_inst_addr <= fet_pc;
                    end
                    if (!flush && tmp_lsb_load_enable) begin
                        tmp_load_data <= 1'b1;
                        tmp_addr      <= lsb_mem_addr;
                        tmp_id        <= lsb_mem_id;
                        tmp_unsigned  <= (lsb_mem_op == `LBU || lsb_mem_op == `LHU);
                        tmp_state     <= (lsb_mem_op == `LW ? STATE_WORD : (lsb_mem_op == `LH || lsb_mem_op == `LHU ? STATE_HALF : STATE_BYTE));
                    end else if (tmp_lsb_store_enable) begin
                        tmp_store_data <= 1'b1;
                        tmp_addr       <= lsb_mem_addr;
                        tmp_data       <= lsb_mem_data;
                        tmp_state      <= (lsb_mem_op == `SW ? STATE_WORD : (lsb_mem_op == `SH ? STATE_HALF : STATE_BYTE));
                    end
                    if (!flush && tmp_lsb_load_enable) begin
                        if (tmp_io && io_buffer_full) begin
                            tmp_io_delay <= 1'b1;
                        end else begin
                            mem_ram_addr <= lsb_mem_addr;
                            mem_ram_wr   <= 1'b0;
                        end
                    end else if (tmp_lsb_store_enable) begin
                        if (tmp_io && io_buffer_full) begin
                            tmp_io_delay <= 1'b1;
                        end else begin
                            mem_ram_data <= lsb_mem_data[7 : 0];
                            mem_ram_addr <= lsb_mem_addr;
                            mem_ram_wr   <= 1'b1;
                        end
                    end else if (!flush && fet_mem_enable) begin
                        mem_ram_addr <= fet_pc;
                        mem_ram_wr   <= 1'b0;
                    end
                end else begin
                    if (!flush && (tmp_load_data || tmp_load_inst) && tmp_offset != 2'd0) begin
                        case (tmp_offset)
                            2'd0: ;
                            2'd1: tmp_load_res[7 : 0] <= ram_data;
                            2'd2: tmp_load_res[15 : 8] <= ram_data;
                            2'd3: tmp_load_res[23 : 16] <= ram_data;
                        endcase
                    end
                    if (!flush && tmp_load_data) begin
                        if (tmp_offset == tmp_state) begin
                            mem_id <= tmp_id;
                            if (tmp_load_inst) begin
                                mem_ram_addr <= tmp_inst_addr;
                            end else begin
                                mem_ram_addr <= `XLEN'b0;
                                tmp_busy     <= 1'b0;
                            end
                            tmp_load_data   <= 1'b0;
                            tmp_offset      <= 2'd0;
                            tmp_last_offset <= tmp_offset;
                        end else begin
                            mem_ram_addr <= tmp_addr + tmp_offset + `XLEN'd1;
                            tmp_offset   <= tmp_offset + 2'd1;
                        end
                    end else if (tmp_store_data) begin
                        if (tmp_offset == tmp_state) begin
                            mem_ram_wr <= 1'b0;
                            if (!flush && tmp_load_inst) begin
                                mem_ram_addr <= tmp_inst_addr;
                            end else begin
                                mem_ram_addr <= `XLEN'b0;
                                tmp_busy     <= 1'b0;
                            end
                            tmp_store_data <= 1'b0;
                            tmp_offset     <= 2'd0;
                        end else begin
                            case (tmp_offset)
                                2'd0: mem_ram_data <= tmp_data[15 : 8];
                                2'd1: mem_ram_data <= tmp_data[23 : 16];
                                2'd2: mem_ram_data <= tmp_data[31 : 24];
                                2'd3: ;
                            endcase
                            mem_ram_addr <= tmp_addr + tmp_offset + `XLEN'd1;
                            tmp_offset   <= tmp_offset + 2'd1;
                        end
                    end else if (!flush && tmp_load_inst) begin
                        if (tmp_mem_inst_ready) begin
                            mem_inst_addr   <= tmp_inst_addr;
                            mem_ram_addr    <= `XLEN'b0;
                            tmp_busy        <= 1'b0;
                            tmp_load_inst   <= 1'b0;
                            tmp_offset      <= 2'b0;
                            tmp_last_offset <= tmp_offset;
                        end else begin
                            mem_ram_addr <= tmp_inst_addr + tmp_offset + `XLEN'd1;
                            tmp_offset   <= tmp_offset + 2'd1;
                        end
                    end
                end
            end else if (!io_buffer_full) begin
                tmp_io_delay <= 1'b0;
                if (tmp_load_data) begin
                    mem_data_ready <= 1'b1;
                    mem_ram_addr   <= tmp_addr;
                    mem_ram_wr     <= 1'b0;
                end
                if (tmp_store_data) begin
                    mem_ram_data <= tmp_data[7 : 0];
                    mem_ram_addr <= tmp_addr;
                    mem_ram_wr   <= 1'b1;
                end
            end
        end else begin
            if (tmp_io && io_buffer_full) begin
                mem_ram_data <= 8'b0;
                mem_ram_addr <= `XLEN'b0;
                mem_ram_wr   <= 1'b0;
            end
        end
    end
endmodule
