// RISCV32 CPU top module
// port modification allowed for debugging purposes

`include "global_params.v"

module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17:0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31 : 0] dbgreg_dout  // cpu register output (debugging demo)
);
    wire                             flush;
    wire                             stall;

    // ALU
    wire                             alu_ready;
    wire [            `XLEN - 1 : 0] alu_res;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] alu_id;

    // Branch Predictor
    wire                             bp_pred;
    wire [            `XLEN - 1 : 0] bp_corret_cnt;
    wire [            `XLEN - 1 : 0] bp_total_cnt;

    // Decoder
    wire                             dec_stall;
    wire                             dec_ready;
    wire [   `INST_OP_WIDTH - 1 : 0] dec_op;
    wire                             dec_jump_pred;
    wire [   `REG_CNT_WIDTH - 1 : 0] dec_rd;
    wire [   `REG_CNT_WIDTH - 1 : 0] dec_rs1;
    wire [   `REG_CNT_WIDTH - 1 : 0] dec_rs2;
    wire [            `XLEN - 1 : 0] dec_imm;
    wire [            `XLEN - 1 : 0] dec_inst_addr;
    wire                             dec_c_extension;

    // Fetcher
    wire                             fet_mem_enable;
    wire                             fet_ready;
    wire [            `XLEN - 1 : 0] fet_inst;
    wire [            `XLEN - 1 : 0] fet_inst_addr;
    wire                             fet_jump_pred;
    wire                             fet_icache_enable;
    wire [            `XLEN - 1 : 0] fet_pc;

    // Icache
    wire                             icache_ready;
    wire [            `XLEN - 1 : 0] icache_inst;

    // LSB
    wire                             lsb_full;
    wire                             lsb_empty;
    wire [   `INST_OP_WIDTH - 1 : 0] lsb_front_op;
    wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q1;
    wire [            `XLEN - 1 : 0] lsb_front_V1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] lsb_front_Q2;
    wire [            `XLEN - 1 : 0] lsb_front_V2;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] lsb_front_id;
    wire                             lsb_mem_enable;
    wire [   `INST_OP_WIDTH - 1 : 0] lsb_mem_op;
    wire [            `XLEN - 1 : 0] lsb_mem_addr;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] lsb_mem_id;

    // Memory Controller
    wire                             mem_busy;
    wire                             mem_fet_busy;
    wire [            `XLEN - 1 : 0] mem_inst;
    wire [            `XLEN - 1 : 0] mem_data;
    wire                             mem_inst_ready;
    wire [            `XLEN - 1 : 0] mem_inst_addr;
    wire                             mem_data_ready;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] mem_id;

    // RF
    wire [            `XLEN - 1 : 0] rf_val1;
    wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep1;
    wire [            `XLEN - 1 : 0] rf_val2;
    wire [`DEPENDENCY_WIDTH - 1 : 0] rf_dep2;

    // ROB
    wire                             rob_full;
    wire                             rob_Q1_ready;
    wire [            `XLEN - 1 : 0] rob_Q1_val;
    wire                             rob_Q2_ready;
    wire [            `XLEN - 1 : 0] rob_Q2_val;
    wire [   `INST_OP_WIDTH - 1 : 0] rob_rs_remove_op;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] rob_head_id;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] rob_tail_id;
    wire                             rob_flush;
    wire [            `XLEN - 1 : 0] rob_correct_pc;
    wire                             rob_bp_enable;
    wire [            `XLEN - 1 : 0] rob_bp_inst_addr;
    wire                             rob_bp_jump;
    wire                             rob_bp_correct;
    wire                             rob_mem_enable;
    wire [   `INST_OP_WIDTH - 1 : 0] rob_mem_op;
    wire [            `XLEN - 1 : 0] rob_mem_addr;
    wire [            `XLEN - 1 : 0] rob_mem_val;
    wire                             rob_rf_enable;
    wire [   `REG_CNT_WIDTH - 1 : 0] rob_rf_rd;
    wire [            `XLEN - 1 : 0] rob_rf_val;

    // RS
    wire [  `ROB_SIZE_WIDTH - 1 : 0] rs_remove_id;
    wire                             rs_full;
    wire                             rs_ready;
    wire [    `ALU_OP_WIDTH - 1 : 0] rs_op;
    wire [            `XLEN - 1 : 0] rs_val1;
    wire [            `XLEN - 1 : 0] rs_val2;
    wire [  `ROB_SIZE_WIDTH - 1 : 0] rs_id;

    assign flush = rob_flush;
    assign stall = dec_stall;

    alu my_alu (
        .clk      (clk_in),
        .rst      (rst_in),
        .rdy      (rdy_in),
        .flush    (flush),
        .rs_ready (rs_ready),
        .rs_op    (rs_op),
        .rs_val1  (rs_val1),
        .rs_val2  (rs_val2),
        .rs_id    (rs_id),
        .alu_ready(alu_ready),
        .alu_res  (alu_res),
        .alu_id   (alu_id)
    );

    branch_predictor my_bp (
        .clk             (clk_in),
        .rst             (rst_in),
        .rdy             (rdy_in),
        .flush           (flush),
        .fet_pc          (fet_pc),
        .rob_bp_enable   (rob_bp_enable),
        .rob_bp_inst_addr(rob_bp_inst_addr),
        .rob_bp_jump     (rob_bp_jump),
        .rob_bp_correct  (rob_bp_correct),
        .bp_pred         (bp_pred),
        .bp_corret_cnt   (bp_corret_cnt),
        .bp_total_cnt    (bp_total_cnt)
    );

    decoder my_dec (
        .clk            (clk_in),
        .rst            (rst_in),
        .rdy            (rdy_in),
        .flush          (flush),
        .fet_ready      (fet_ready),
        .fet_inst       (fet_inst),
        .fet_inst_addr  (fet_inst_addr),
        .fet_jump_pred  (fet_jump_pred),
        .lsb_full       (lsb_full),
        .rob_full       (rob_full),
        .rs_full        (rs_full),
        .dec_stall      (dec_stall),
        .dec_ready      (dec_ready),
        .dec_op         (dec_op),
        .dec_jump_pred  (dec_jump_pred),
        .dec_rd         (dec_rd),
        .dec_rs1        (dec_rs1),
        .dec_rs2        (dec_rs2),
        .dec_imm        (dec_imm),
        .dec_inst_addr  (dec_inst_addr),
        .dec_c_extension(dec_c_extension)
    );

    fetcher my_fet (
        .clk              (clk_in),
        .rst              (rst_in),
        .rdy              (rdy_in),
        .flush            (flush),
        .stall            (stall),
        .bp_pred          (bp_pred),
        .icache_ready     (icache_ready),
        .icache_inst      (icache_inst),
        .mem_fet_busy     (mem_fet_busy),
        .mem_inst_ready   (mem_inst_ready),
        .mem_inst         (mem_inst),
        .rob_correct_pc   (rob_correct_pc),
        .fet_mem_enable   (fet_mem_enable),
        .fet_ready        (fet_ready),
        .fet_inst         (fet_inst),
        .fet_inst_addr    (fet_inst_addr),
        .fet_jump_pred    (fet_jump_pred),
        .fet_icache_enable(fet_icache_enable),
        .fet_pc           (fet_pc)
    );

    icache my_icache (
        .clk              (clk_in),
        .rst              (rst_in),
        .rdy              (rdy_in),
        .flush            (flush),
        .stall            (stall),
        .fet_icache_enable(fet_icache_enable),
        .fet_pc           (fet_pc),
        .mem_busy         (mem_busy),
        .mem_inst_ready   (mem_inst_ready),
        .mem_inst         (mem_inst),
        .mem_inst_addr    (mem_inst_addr),
        .icache_ready     (icache_ready),
        .icache_inst      (icache_inst)
    );

    load_store_buffer my_lsb (
        .clk           (clk_in),
        .rst           (rst_in),
        .rdy           (rdy_in),
        .flush         (flush),
        .stall         (stall),
        .io_buffer_full(io_buffer_full),
        .alu_ready     (alu_ready),
        .alu_res       (alu_res),
        .alu_id        (alu_id),
        .dec_ready     (dec_ready),
        .dec_op        (dec_op),
        .dec_jump_pred (dec_jump_pred),
        .dec_rd        (dec_rd),
        .dec_rs1       (dec_rs1),
        .dec_rs2       (dec_rs2),
        .dec_imm       (dec_imm),
        .dec_inst_addr (dec_inst_addr),
        .mem_busy      (mem_busy),
        .mem_data_ready(mem_data_ready),
        .mem_data      (mem_data),
        .mem_id        (mem_id),
        .rf_val1       (rf_val1),
        .rf_dep1       (rf_dep1),
        .rf_val2       (rf_val2),
        .rf_dep2       (rf_dep2),
        .rob_mem_enable(rob_mem_enable),
        .rob_Q1_ready  (rob_Q1_ready),
        .rob_Q1_val    (rob_Q1_val),
        .rob_Q2_ready  (rob_Q2_ready),
        .rob_Q2_val    (rob_Q2_val),
        .rob_head_id   (rob_head_id),
        .rob_tail_id   (rob_tail_id),
        .lsb_full      (lsb_full),
        .lsb_empty     (lsb_empty),
        .lsb_front_op  (lsb_front_op),
        .lsb_front_Q1  (lsb_front_Q1),
        .lsb_front_V1  (lsb_front_V1),
        .lsb_front_Q2  (lsb_front_Q2),
        .lsb_front_V2  (lsb_front_V2),
        .lsb_front_id  (lsb_front_id),
        .lsb_mem_enable(lsb_mem_enable),
        .lsb_mem_op    (lsb_mem_op),
        .lsb_mem_addr  (lsb_mem_addr),
        .lsb_mem_id    (lsb_mem_id)
    );

    memory_controller my_mem (
        .clk           (clk_in),
        .rst           (rst_in),
        .rdy           (rdy_in),
        .flush         (flush),
        .stall         (stall),
        .fet_mem_enable(fet_mem_enable),
        .fet_pc        (fet_pc),
        .lsb_mem_enable(lsb_mem_enable),
        .lsb_mem_op    (lsb_mem_op),
        .lsb_mem_addr  (lsb_mem_addr),
        .lsb_mem_id    (lsb_mem_id),
        .ram_data      (mem_din),
        .rob_mem_enable(rob_mem_enable),
        .rob_mem_op    (rob_mem_op),
        .rob_mem_addr  (rob_mem_addr),
        .rob_mem_val   (rob_mem_val),
        .mem_busy      (mem_busy),
        .mem_fet_busy  (mem_fet_busy),
        .mem_inst      (mem_inst),
        .mem_data      (mem_data),
        .mem_inst_ready(mem_inst_ready),
        .mem_inst_addr (mem_inst_addr),
        .mem_data_ready(mem_data_ready),
        .mem_id        (mem_id),
        .mem_ram_data  (mem_dout),
        .mem_ram_addr  (mem_a),
        .mem_ram_wr    (mem_wr)
    );

    register_file my_rf (
        .clk          (clk_in),
        .rst          (rst_in),
        .rdy          (rdy_in),
        .flush        (flush),
        .stall        (stall),
        .dec_ready    (dec_ready),
        .dec_op       (dec_op),
        .dec_rd       (dec_rd),
        .dec_rs1      (dec_rs1),
        .dec_rs2      (dec_rs2),
        .rob_rf_enable(rob_rf_enable),
        .rob_rf_rd    (rob_rf_rd),
        .rob_rf_val   (rob_rf_val),
        .rob_head_id  (rob_head_id),
        .rob_tail_id  (rob_tail_id),
        .rf_val1      (rf_val1),
        .rf_dep1      (rf_dep1),
        .rf_val2      (rf_val2),
        .rf_dep2      (rf_dep2)
    );

    reorder_buffer my_rob (
        .clk             (clk_in),
        .rst             (rst_in),
        .rdy             (rdy_in),
        .flush           (flush),
        .stall           (stall),
        .io_buffer_full  (io_buffer_full),
        .alu_ready       (alu_ready),
        .alu_res         (alu_res),
        .alu_id          (alu_id),
        .dec_ready       (dec_ready),
        .dec_op          (dec_op),
        .dec_jump_pred   (dec_jump_pred),
        .dec_rd          (dec_rd),
        .dec_rs1         (dec_rs1),
        .dec_rs2         (dec_rs2),
        .dec_imm         (dec_imm),
        .dec_inst_addr   (dec_inst_addr),
        .dec_c_extension (dec_c_extension),
        .lsb_empty       (lsb_empty),
        .lsb_front_op    (lsb_front_op),
        .lsb_front_id    (lsb_front_id),
        .lsb_front_Q1    (lsb_front_Q1),
        .lsb_front_V1    (lsb_front_V1),
        .lsb_front_Q2    (lsb_front_Q2),
        .lsb_front_V2    (lsb_front_V2),
        .mem_busy        (mem_busy),
        .mem_data_ready  (mem_data_ready),
        .mem_data        (mem_data),
        .mem_id          (mem_id),
        .rf_dep1         (rf_dep1),
        .rf_dep2         (rf_dep2),
        .rs_remove_id    (rs_remove_id),
        .rob_full        (rob_full),
        .rob_Q1_ready    (rob_Q1_ready),
        .rob_Q1_val      (rob_Q1_val),
        .rob_Q2_ready    (rob_Q2_ready),
        .rob_Q2_val      (rob_Q2_val),
        .rob_rs_remove_op(rob_rs_remove_op),
        .rob_head_id     (rob_head_id),
        .rob_tail_id     (rob_tail_id),
        .rob_flush       (rob_flush),
        .rob_correct_pc  (rob_correct_pc),
        .rob_bp_enable   (rob_bp_enable),
        .rob_bp_inst_addr(rob_bp_inst_addr),
        .rob_bp_jump     (rob_bp_jump),
        .rob_bp_correct  (rob_bp_correct),
        .rob_mem_enable  (rob_mem_enable),
        .rob_mem_op      (rob_mem_op),
        .rob_mem_addr    (rob_mem_addr),
        .rob_mem_val     (rob_mem_val),
        .rob_rf_enable   (rob_rf_enable),
        .rob_rf_rd       (rob_rf_rd),
        .rob_rf_val      (rob_rf_val)
    );

    reservation_station my_rs (
        .clk             (clk_in),
        .rst             (rst_in),
        .rdy             (rdy_in),
        .flush           (flush),
        .stall           (stall),
        .alu_ready       (alu_ready),
        .alu_res         (alu_res),
        .alu_id          (alu_id),
        .dec_ready       (dec_ready),
        .dec_op          (dec_op),
        .dec_jump_pred   (dec_jump_pred),
        .dec_rd          (dec_rd),
        .dec_rs1         (dec_rs1),
        .dec_rs2         (dec_rs2),
        .dec_imm         (dec_imm),
        .mem_data_ready  (mem_data_ready),
        .mem_data        (mem_data),
        .mem_id          (mem_id),
        .rf_val1         (rf_val1),
        .rf_dep1         (rf_dep1),
        .rf_val2         (rf_val2),
        .rf_dep2         (rf_dep2),
        .rob_Q1_ready    (rob_Q1_ready),
        .rob_Q1_val      (rob_Q1_val),
        .rob_Q2_ready    (rob_Q2_ready),
        .rob_Q2_val      (rob_Q2_val),
        .rob_rs_remove_op(rob_rs_remove_op),
        .rob_tail_id     (rob_tail_id),
        .rs_remove_id    (rs_remove_id),
        .rs_full         (rs_full),
        .rs_ready        (rs_ready),
        .rs_op           (rs_op),
        .rs_val1         (rs_val1),
        .rs_val2         (rs_val2),
        .rs_id           (rs_id)
    );
endmodule
