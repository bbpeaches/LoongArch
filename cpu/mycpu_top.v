
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        clk_sram,
    input  wire        resetn_sram,

    output wire        pipe_go,
    output wire [1:0]  pipe_idx,
    input  wire        pipe_busy_s,
    input  wire        pipe_done_s,
    input  wire        pipe_giveup_s,
    input  wire [31:0] pipe_retarget_pc_s,

    // AXI
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire        inst_sram_req;
    wire [31:0] inst_sram_addr;
    wire        inst_sram_addr_ok;
    wire        inst_sram_data_ok;
    wire [31:0] inst_sram_rdata;

    wire        cpu_data_req;
    wire        cpu_data_wr;
    wire [ 1:0] cpu_data_size;
    wire [31:0] cpu_data_addr;
    wire [ 3:0] cpu_data_wstrb;
    wire [31:0] cpu_data_wdata;
    wire        cpu_data_addr_ok;
    wire        cpu_data_data_ok;
    wire [31:0] cpu_data_rdata;

    wire        wb_data_req;
    wire        wb_data_wr;
    wire [ 1:0] wb_data_size;
    wire [31:0] wb_data_addr;
    wire [ 3:0] wb_data_wstrb;
    wire [31:0] wb_data_wdata;
    wire        wb_data_addr_ok;
    wire        wb_data_data_ok;
    wire [31:0] wb_data_rdata;
    wire        wb_empty;
    wire        data_idle;
    wire        icache_idle;

    wire        icache_arvalid, icache_arready, icache_rlast, icache_rvalid, icache_rready;
    wire [31:0] icache_araddr, icache_rdata;

    wire        debug_wb_rf_wen_1bit;
    assign debug_wb_rf_we = {4{debug_wb_rf_wen_1bit}};

    wire        pipe_hold;
    wire        pipe_retarget_en;
    wire [31:0] pipe_retarget_pc;
    wire        soft_idle;
    wire [31:0] if_pc_sniff;
    wire        if_pc_sniff_ok;

    assign if_pc_sniff    = inst_sram_addr;
    assign if_pc_sniff_ok = inst_sram_req && inst_sram_addr_ok;
    assign soft_idle      = wb_empty && data_idle && icache_idle;

    cpu u_cpu (
        .clk                (aclk),
        .resetn             (aresetn),
        .pipe_hold          (pipe_hold),
        .pipe_retarget_en   (pipe_retarget_en),
        .pipe_retarget_pc   (pipe_retarget_pc),

        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (),
        .inst_sram_size     (),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_wstrb    (),
        .inst_sram_wdata    (),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),

        .data_sram_req      (cpu_data_req),
        .data_sram_wr       (cpu_data_wr),
        .data_sram_size     (cpu_data_size),
        .data_sram_addr     (cpu_data_addr),
        .data_sram_wstrb    (cpu_data_wstrb),
        .data_sram_wdata    (cpu_data_wdata),
        .data_sram_addr_ok  (cpu_data_addr_ok),
        .data_sram_data_ok  (cpu_data_data_ok),
        .data_sram_rdata    (cpu_data_rdata),

        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_wen    (debug_wb_rf_wen_1bit),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata)
    );

    write_buffer #(
        .DEPTH(4)
    ) u_wb (
        .clk            (aclk),
        .resetn         (aresetn),

        .cpu_req        (cpu_data_req),
        .cpu_wr         (cpu_data_wr),
        .cpu_size       (cpu_data_size),
        .cpu_addr       (cpu_data_addr),
        .cpu_wstrb      (cpu_data_wstrb),
        .cpu_wdata      (cpu_data_wdata),
        .cpu_addr_ok    (cpu_data_addr_ok),
        .cpu_data_ok    (cpu_data_data_ok),
        .cpu_rdata      (cpu_data_rdata),

        .mem_req        (wb_data_req),
        .mem_wr         (wb_data_wr),
        .mem_size       (wb_data_size),
        .mem_addr       (wb_data_addr),
        .mem_wstrb      (wb_data_wstrb),
        .mem_wdata      (wb_data_wdata),
        .mem_addr_ok    (wb_data_addr_ok),
        .mem_data_ok    (wb_data_data_ok),
        .mem_rdata      (wb_data_rdata),
        .wb_empty       (wb_empty)
    );

    icache u_icache (
        .clk            (aclk),
        .resetn         (aresetn),
        .cpu_req        (inst_sram_req),
        .cpu_addr       (inst_sram_addr),
        .cache_rdata    (inst_sram_rdata),
        .cache_addr_ok  (inst_sram_addr_ok),
        .cache_data_ok  (inst_sram_data_ok),

        .arid           (),
        .araddr         (icache_araddr),
        .arvalid        (icache_arvalid),
        .arready        (icache_arready),
        .rid            (4'd0),
        .rdata          (icache_rdata),
        .rlast          (icache_rlast),
        .rvalid         (icache_rvalid),
        .rready         (icache_rready)
    );

    sram_axi_bridge u_bridge (
        .clk                (aclk),
        .resetn             (aresetn),

        .icache_araddr      (icache_araddr),
        .icache_arvalid     (icache_arvalid),
        .icache_arready     (icache_arready),
        .icache_rdata       (icache_rdata),
        .icache_rlast       (icache_rlast),
        .icache_rvalid      (icache_rvalid),
        .icache_rready      (icache_rready),

        .data_req           (wb_data_req),
        .data_wr            (wb_data_wr),
        .data_size          (wb_data_size),
        .data_addr          (wb_data_addr),
        .data_wstrb         (wb_data_wstrb),
        .data_wdata         (wb_data_wdata),
        .data_addr_ok       (wb_data_addr_ok),
        .data_data_ok       (wb_data_data_ok),
        .data_rdata         (wb_data_rdata),
        .data_idle          (data_idle),
        .icache_idle        (icache_idle),

        .arid               (arid),
        .araddr             (araddr),
        .arlen              (arlen),
        .arsize             (arsize),
        .arburst            (arburst),
        .arlock             (arlock),
        .arcache            (arcache),
        .arprot             (arprot),
        .arvalid            (arvalid),
        .arready            (arready),
        .rid                (rid),
        .rdata              (rdata),
        .rresp              (rresp),
        .rlast              (rlast),
        .rvalid             (rvalid),
        .rready             (rready),

        .awid               (awid),
        .awaddr             (awaddr),
        .awlen              (awlen),
        .awsize             (awsize),
        .awburst            (awburst),
        .awlock             (awlock),
        .awcache            (awcache),
        .awprot             (awprot),
        .awvalid            (awvalid),
        .awready            (awready),

        .wid                (wid),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .wlast              (wlast),
        .wvalid             (wvalid),
        .wready             (wready),

        .bid                (bid),
        .bresp              (bresp),
        .bvalid             (bvalid),
        .bready             (bready)
    );

  
    la_accel_unit #(
        .ENABLE_MASK(4'b0111)
    ) u_accel (
        .clk_cpu(aclk), .resetn_cpu(aresetn),
        .clk_sram(clk_sram), .resetn_sram(resetn_sram),
        .if_addr(if_pc_sniff), .if_addr_ok(if_pc_sniff_ok),
        .soft_idle(soft_idle),
        .pipe_hold(pipe_hold),
        .pipe_retarget_en(pipe_retarget_en),
        .pipe_retarget_pc(pipe_retarget_pc),
        .pipe_go(pipe_go), .pipe_idx(pipe_idx),
        .pipe_busy_s(pipe_busy_s), .pipe_done_s(pipe_done_s),
        .pipe_giveup_s(pipe_giveup_s), .pipe_retarget_pc_s(pipe_retarget_pc_s)
    );

endmodule
