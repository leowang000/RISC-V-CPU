`include "global_params.v"

module branch_predictor (
    // input
    input wire clk,
    input wire rst,
    input wire rdy,

    // from Fetcher
    input wire [`XLEN - 1 : 0] fet_inst_addr,

    // from ROB
    input wire                 rob_bp_enable,
    input wire [`XLEN - 1 : 0] rob_bp_inst_addr,
    input wire                 rob_bp_jump,
    input wire                 rob_bp_correct,

    // output
    output wire                 bp_pred,
    output wire [`XLEN - 1 : 0] bp_corret_cnt,  // for branch prediction accuracy
    output wire [`XLEN - 1 : 0] bp_total_cnt    // for branch prediction accuracy
);
    reg [        1 : 0] predictor       [`BP_SIZE - 1 : 0];
    reg [`XLEN - 1 : 0] total_counter   [`BP_SIZE - 1 : 0];
    reg [`XLEN - 1 : 0] correct_counter [`BP_SIZE - 1 : 0];

    reg [`XLEN - 1 : 0] tmp_total_sum;
    reg [`XLEN - 1 : 0] tmp_correct_sum;

    assign bp_pred       = predictor[fet_inst_addr[`BP_SIZE_WIDTH-1 : 0]];
    assign bp_corret_cnt = tmp_correct_sum;
    assign bp_total_cnt  = tmp_total_sum;

    initial begin
        for (integer i = 0; i < `BP_SIZE; i = i + 1) begin
            predictor[i]       = 2'b0;
            total_counter[i]   = `XLEN'b0;
            correct_counter[i] = `XLEN'b0;
        end
        tmp_total_sum   = `XLEN'b0;
        tmp_correct_sum = `XLEN'b0;
    end

    always @(*) begin
        tmp_total_sum = `XLEN'b0;
        for (integer i = 0; i < `BP_SIZE; i = i + 1) begin
            tmp_total_sum = tmp_total_sum + total_counter[i];
        end
    end

    always @(*) begin
        tmp_correct_sum = `XLEN'b0;
        for (integer i = 0; i < `BP_SIZE; i = i + 1) begin
            tmp_correct_sum = tmp_correct_sum + correct_counter[i];
        end
    end

    always @(posedge clk) begin
        if (rdy) begin
            if (rst) begin
                for (integer i = 0; i < `BP_SIZE; i = i + 1) begin
                    predictor[i]       <= 2'b0;
                    total_counter[i]   <= `XLEN'b0;
                    correct_counter[i] <= `XLEN'b0;
                end
            end else if (rob_bp_enable) begin
                if (predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] != 2'b11 && rob_bp_jump) begin
                    predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] <= predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] + 1;
                end
                if (predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] != 2'b00 && !rob_bp_jump) begin
                    predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] <= predictor[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] - 1;
                end
                total_counter[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]]   <= total_counter[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] + `XLEN'b1;
                correct_counter[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] <= correct_counter[rob_bp_inst_addr[`BP_SIZE_WIDTH-1 : 0]] + (rob_bp_correct ? `XLEN'b1 : `XLEN'b0);
            end
        end
    end
endmodule
