module thinpad_top(
    input wire clk_50M,
    input wire clk_11M0592,
    input wire clock_btn,
    input wire reset_btn,
    input  wire[3:0]  touch_btn,
    input  wire[31:0] dip_sw,
    output wire[15:0] leds,
    output wire[7:0]  dpy0,
    output wire[7:0]  dpy1,

    inout wire[31:0] base_ram_data,
    output wire[19:0] base_ram_addr,
    output wire[3:0] base_ram_be_n,
    output wire base_ram_ce_n,
    output wire base_ram_oe_n,
    output wire base_ram_we_n,

    inout wire[31:0] ext_ram_data,
    output wire[19:0] ext_ram_addr,
    output wire[3:0] ext_ram_be_n,
    output wire ext_ram_ce_n,
    output wire ext_ram_oe_n,
    output wire ext_ram_we_n,

    output wire txd,
    input  wire rxd,

    output wire [22:0]flash_a,
    inout  wire [15:0]flash_d,
    output wire flash_rp_n,
    output wire flash_vpen,
    output wire flash_ce_n,
    output wire flash_oe_n,
    output wire flash_we_n,
    output wire flash_byte_n,

    output wire[2:0] video_red,
    output wire[2:0] video_green,
    output wire[1:0] video_blue,
    output wire video_hsync,
    output wire video_vsync,
    output wire video_clk,
    output wire video_de
);

wire locked, clk_cpu, clk_sram_unused;
wire clk_sram = clk_cpu;
pll_example clock_gen (
  .clk_in1(clk_50M),
  .clk_out1(clk_cpu),
  .clk_out2(clk_sram_unused),
  .reset(reset_btn),
  .locked(locked)
);

reg cpu_reset_sync;
always @(posedge clk_cpu or negedge locked) begin
    if (~locked) cpu_reset_sync <= 1'b0;
    else         cpu_reset_sync <= 1'b1;
end
wire cpu_resetn = cpu_reset_sync;
wire sram_resetn = cpu_resetn;

wire [ 3:0] arid_sram, arlen_sram, arcache_sram, awid_sram, awlen_sram, awcache_sram, wid_sram, wstrb_sram, rid_sram, bid_sram;
wire [31:0] araddr_sram, rdata_sram, awaddr_sram, wdata_sram;
wire [ 2:0] arsize_sram, arprot_sram, awsize_sram, awprot_sram;
wire [ 1:0] arburst_sram, arlock_sram, awburst_sram, awlock_sram, rresp_sram, bresp_sram;
wire arvalid_sram, arready_sram, rlast_sram, rvalid_sram, rready_sram;
wire awvalid_sram, awready_sram, wlast_sram, wvalid_sram, wready_sram;
wire bvalid_sram, bready_sram;

mycpu_top u_cpu (
    .aclk       (clk_cpu),
    .aresetn    (cpu_resetn),

    .arid       (arid_sram),
    .araddr     (araddr_sram),
    .arlen      (arlen_sram),
    .arsize     (arsize_sram),
    .arburst    (arburst_sram),
    .arlock     (arlock_sram),
    .arcache    (arcache_sram),
    .arprot     (arprot_sram),
    .arvalid    (arvalid_sram),
    .arready    (arready_sram),

    .rid        (rid_sram),
    .rdata      (rdata_sram),
    .rresp      (rresp_sram),
    .rlast      (rlast_sram),
    .rvalid     (rvalid_sram),
    .rready     (rready_sram),

    .awid       (awid_sram),
    .awaddr     (awaddr_sram),
    .awlen      (awlen_sram),
    .awsize     (awsize_sram),
    .awburst    (awburst_sram),
    .awlock     (awlock_sram),
    .awcache    (awcache_sram),
    .awprot     (awprot_sram),
    .awvalid    (awvalid_sram),
    .awready    (awready_sram),

    .wid        (wid_sram),
    .wdata      (wdata_sram),
    .wstrb      (wstrb_sram),
    .wlast      (wlast_sram),
    .wvalid     (wvalid_sram),
    .wready     (wready_sram),

    .bid        (bid_sram),
    .bresp      (bresp_sram),
    .bvalid     (bvalid_sram),
    .bready     (bready_sram),

    .debug_wb_pc(), .debug_wb_rf_we(), .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_buffer;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
reg  ext_uart_start, ext_uart_avai;

async_receiver #(.ClkFrequency(130000000), .Baud(115200)) ext_uart_r (
    .clk(clk_sram),
    .RxD(rxd),
    .RxD_data_ready(ext_uart_ready),
    .RxD_clear(ext_uart_clear),
    .RxD_data(ext_uart_rx)
);

assign ext_uart_clear = ext_uart_ready;
async_transmitter #(.ClkFrequency(130000000), .Baud(115200)) ext_uart_t (
    .clk(clk_sram),
    .TxD(txd),
    .TxD_busy(ext_uart_busy),
    .TxD_start(ext_uart_start),
    .TxD_data(ext_uart_tx)
);

reg [1:0] slave_state;
localparam S_IDLE  = 2'd0;
localparam S_READ  = 2'd1;
localparam S_WRITE = 2'd2;
localparam [1:0] READ_WAIT_CYCLES  = 2'd1;
// Soft Ext write: commit as soon as AW+W are captured (LoongArch CRN pipe used 0).
localparam [1:0] WRITE_WAIT_CYCLES = 2'd0;

always @(posedge clk_sram) begin
    if (!sram_resetn) begin
        slave_state <= S_IDLE;
    end else begin
        case (slave_state)
            S_IDLE: begin
                if (arvalid_sram) slave_state <= S_READ;
                else if (awvalid_sram || wvalid_sram) slave_state <= S_WRITE;
            end
            S_READ: begin
                if (rvalid_sram && rready_sram && rlast_sram) begin
                    // Zero-idle: chain into a pending write without an IDLE beat.
                    if (awvalid_sram || wvalid_sram) slave_state <= S_WRITE;
                    else slave_state <= S_IDLE;
                end
            end
            S_WRITE: begin
                if (bvalid_sram && bready_sram) begin
                    if (arvalid_sram) slave_state <= S_READ;
                    else if (awvalid_sram || wvalid_sram) slave_state <= S_WRITE;
                    else slave_state <= S_IDLE;
                end
            end
        endcase
    end
end

wire read_complete  = (slave_state == S_READ)  && rvalid_sram && rready_sram && rlast_sram;
wire write_complete = (slave_state == S_WRITE) && bvalid_sram && bready_sram;

wire is_read  = (slave_state == S_READ) ||
                (slave_state == S_IDLE && arvalid_sram) ||
                (write_complete && arvalid_sram);
wire is_write = (slave_state == S_WRITE) ||
                (slave_state == S_IDLE && !arvalid_sram && (awvalid_sram || wvalid_sram)) ||
                (read_complete && (awvalid_sram || wvalid_sram));

reg rvalid_reg;
reg [31:0] raddr_reg;
reg [3:0]  rid_reg;
reg [7:0]  rlen_reg;
reg [1:0]  rburst_reg;
reg [7:0]  rbeat_cnt;
reg [1:0]  rwait_cnt;

assign arready_sram = (slave_state == S_IDLE) ||
                      ((slave_state == S_WRITE) && bvalid_sram && bready_sram);
wire read_fire = arvalid_sram && arready_sram;

always @(posedge clk_sram) begin
    if (!sram_resetn) begin
        rvalid_reg <= 1'b0;
        raddr_reg  <= 32'd0;
        rid_reg    <= 4'd0;
        rlen_reg   <= 8'd0;
        rburst_reg <= 2'd0;
        rbeat_cnt  <= 8'd0;
        rwait_cnt  <= 2'd0;
    end else if (read_fire) begin
        rvalid_reg <= 1'b0;
        raddr_reg  <= araddr_sram;
        rid_reg    <= arid_sram;
        rlen_reg   <= arlen_sram;
        rburst_reg <= arburst_sram;
        rbeat_cnt  <= 8'd0;
        rwait_cnt  <= 2'd0;
    end else if (slave_state == S_READ) begin
        if (!rvalid_reg) begin
            if (rwait_cnt >= READ_WAIT_CYCLES) begin
                rvalid_reg <= 1'b1;
            end else begin
                rwait_cnt <= rwait_cnt + 2'd1;
            end
        end else if (rready_sram) begin
            if (rbeat_cnt == rlen_reg) begin
                rvalid_reg <= 1'b0;
                rwait_cnt  <= 2'd0;
            end else begin
                rvalid_reg <= 1'b0;
                rwait_cnt  <= 2'd0;
                rbeat_cnt  <= rbeat_cnt + 8'd1;
                if (rburst_reg == 2'b10) begin
                    raddr_reg <= {raddr_reg[31:5], raddr_reg[4:2] + 3'd1, 2'b00};
                end else begin
                    raddr_reg <= raddr_reg + 32'd4;
                end
            end
        end else begin
            rwait_cnt <= rwait_cnt;
        end
    end
end

assign rvalid_sram = rvalid_reg;
assign rlast_sram  = (rbeat_cnt == rlen_reg);
assign rresp_sram  = 2'b0;
assign rid_sram    = rid_reg;

wire [31:0] current_raddr = raddr_reg;

reg aw_recvd, w_recvd;
reg [31:0] awaddr_reg;
reg [31:0] wdata_reg;
reg [ 3:0] wstrb_reg;
reg [ 3:0] bid_reg;
reg bvalid_reg;
reg [1:0]  wwait_cnt;

assign awready_sram = is_write && !aw_recvd && !bvalid_reg;
assign wready_sram  = is_write && !w_recvd  && !bvalid_reg;
wire aw_fire = awvalid_sram && awready_sram;
wire w_fire  = wvalid_sram && wready_sram;

always @(posedge clk_sram) begin
    if (!sram_resetn) begin
        aw_recvd  <= 1'b0;
        w_recvd   <= 1'b0;
        awaddr_reg<= 32'd0;
        wdata_reg <= 32'd0;
        wstrb_reg <= 4'd0;
        bid_reg   <= 4'd0;
        bvalid_reg<= 1'b0;
        wwait_cnt <= 2'd0;
    end else begin
        if (bvalid_sram && bready_sram) begin
            bvalid_reg <= 1'b0;
            aw_recvd   <= 1'b0;
            w_recvd    <= 1'b0;
            wwait_cnt  <= 2'd0;
        end

        if (aw_fire) begin
            aw_recvd <= 1'b1;
            awaddr_reg <= awaddr_sram;
            bid_reg <= awid_sram;
        end
        if (w_fire) begin
            w_recvd <= 1'b1;
            wdata_reg <= wdata_sram;
            wstrb_reg <= wstrb_sram;
        end

        if (slave_state == S_WRITE && aw_recvd && w_recvd && !bvalid_reg) begin
            if (wwait_cnt >= WRITE_WAIT_CYCLES) begin
                bvalid_reg <= 1'b1;
                wwait_cnt  <= 2'd0;
            end else begin
                wwait_cnt <= wwait_cnt + 2'd1;
            end
        end else if (!(aw_recvd && w_recvd) && !bvalid_reg) begin
            wwait_cnt <= 2'd0;
        end
    end
end

assign bvalid_sram = bvalid_reg;
assign bresp_sram  = 2'b0;
assign bid_sram    = bid_reg;

wire do_write = (slave_state == S_WRITE) && aw_recvd && w_recvd && !bvalid_reg;
wire write_commit = do_write && (wwait_cnt >= WRITE_WAIT_CYCLES);
wire [31:0] current_waddr = awaddr_reg;
wire [31:0] current_wdata = wdata_reg;
wire [ 3:0] current_wstrb = wstrb_reg;

wire [31:0] mem_addr = do_write ? current_waddr : current_raddr;
wire        mem_we   = do_write;
wire        mem_re   = (slave_state == S_READ);

wire is_base = (mem_addr[31:22] == 10'h070);
wire is_ext  = (mem_addr[31:22] == 10'h071);
wire is_uart = (mem_addr[31:20] == 12'h1f0);

wire        soft_base_ce_n = ~(is_base && (mem_re || mem_we));
wire        soft_base_we_n = ~(is_base && mem_we);
wire        soft_base_oe_n = ~(is_base && mem_re && !mem_we);
wire [3:0]  soft_base_be_n = (is_base && mem_we) ? ~current_wstrb : 4'b0000;
wire [19:0] soft_base_addr = mem_addr[21:2];
wire [31:0] soft_base_dout = current_wdata;
wire        soft_base_doe  = (is_base && mem_we);

wire        soft_ext_ce_n = ~(is_ext && (mem_re || mem_we));
wire        soft_ext_we_n = ~(is_ext && mem_we);
wire        soft_ext_oe_n = ~(is_ext && mem_re && !mem_we);
wire [3:0]  soft_ext_be_n = (is_ext && mem_we) ? ~current_wstrb : 4'b0000;
wire [19:0] soft_ext_addr = mem_addr[21:2];
wire [31:0] soft_ext_dout = current_wdata;
wire        soft_ext_doe  = (is_ext && mem_we);

assign base_ram_ce_n = soft_base_ce_n;
assign base_ram_we_n = soft_base_we_n;
assign base_ram_oe_n = soft_base_oe_n;
assign base_ram_be_n = soft_base_be_n;
assign base_ram_addr = soft_base_addr;
assign base_ram_data = soft_base_doe ? soft_base_dout : 32'bz;

assign ext_ram_ce_n  = soft_ext_ce_n;
assign ext_ram_we_n  = soft_ext_we_n;
assign ext_ram_oe_n  = soft_ext_oe_n;
assign ext_ram_be_n  = soft_ext_be_n;
assign ext_ram_addr  = soft_ext_addr;
assign ext_ram_data  = soft_ext_doe ? soft_ext_dout : 32'bz;

reg uart_dlab;

always @(posedge clk_sram) begin
    if(!sram_resetn) begin
        ext_uart_start <= 0;
        ext_uart_tx    <= 0;
        uart_dlab      <= 0;
    end else begin
        if (is_uart && write_commit && mem_addr[7:0] == 8'h03) begin
            uart_dlab <= current_wdata[7];
        end

        if (is_uart && write_commit && mem_addr[7:0] == 8'h00 && !uart_dlab) begin
            ext_uart_tx    <= current_wdata[7:0];
            ext_uart_start <= 1;
        end else begin
            ext_uart_start <= 0;
        end
    end
end

always @(posedge clk_sram) begin
    if(!sram_resetn) begin
        ext_uart_avai   <= 0;
        ext_uart_buffer <= 0;
    end else begin
        if (ext_uart_ready) begin
            ext_uart_buffer <= ext_uart_rx;
            ext_uart_avai   <= 1;
        end else if (is_uart && mem_re && !mem_we && mem_addr[7:0] == 8'h00) begin
            ext_uart_avai   <= 0;
        end
    end
end

wire [7:0] uart_status = {2'b00, !ext_uart_busy, 4'b0000, ext_uart_avai};

assign rdata_sram = is_base ? base_ram_data :
                    is_ext  ? ext_ram_data  :
                    is_uart ? (
                        (mem_addr[7:2] == 6'h01) ? {4{uart_status}} :
                        (mem_addr[7:2] == 6'h00) ? {24'd0, ext_uart_buffer} : 32'd0
                    ) : 32'd0;

assign flash_rp_n   = 1'b1;
assign flash_vpen   = 1'b1;
assign flash_ce_n   = 1'b1;
assign flash_oe_n   = 1'b1;
assign flash_we_n   = 1'b1;
assign flash_byte_n = 1'b1;
assign flash_a      = 23'd0;

assign video_red   = 3'b0;
assign video_green = 3'b0;
assign video_blue  = 2'b0;
assign video_hsync = 1'b0;
assign video_vsync = 1'b0;
assign video_clk   = 1'b0;
assign video_de    = 1'b0;

assign leds = 16'd0;
assign dpy0 = 8'd0;
assign dpy1 = 8'd0;

endmodule
