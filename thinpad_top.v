module thinpad_top(
    input wire clk_50M,           // 50MHz
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

wire locked, clk_cpu, clk_sram;
pll_example clock_gen (
  .clk_in1(clk_50M),
  .clk_out1(clk_cpu),   
  .clk_out2(clk_sram),  
  .reset(reset_btn),
  .locked(locked)
);

// 分别为两个时钟域生成同步复位信号
reg cpu_reset_sync;
always @(posedge clk_cpu or negedge locked) begin
    if (~locked) cpu_reset_sync <= 1'b0;
    else         cpu_reset_sync <= 1'b1;
end
wire cpu_resetn = cpu_reset_sync;

reg sram_reset_sync;
always @(posedge clk_sram or negedge locked) begin
    if (~locked) sram_reset_sync <= 1'b0;
    else         sram_reset_sync <= 1'b1;
end
wire sram_resetn = sram_reset_sync;

wire [ 3:0] arid_cpu, arlen_cpu, arcache_cpu, awid_cpu, awlen_cpu, awcache_cpu, wid_cpu, wstrb_cpu, rid_cpu, bid_cpu;
wire [31:0] araddr_cpu, rdata_cpu, awaddr_cpu, wdata_cpu;
wire [ 2:0] arsize_cpu, arprot_cpu, awsize_cpu, awprot_cpu;
wire [ 1:0] arburst_cpu, arlock_cpu, awburst_cpu, awlock_cpu, rresp_cpu, bresp_cpu;
wire arvalid_cpu, arready_cpu, rlast_cpu, rvalid_cpu, rready_cpu;
wire awvalid_cpu, awready_cpu, wlast_cpu, wvalid_cpu, wready_cpu;
wire bvalid_cpu, bready_cpu;

mycpu_top u_cpu (
    .aclk       (clk_cpu),
    .aresetn    (cpu_resetn),
    
    .arid       (arid_cpu),
    .araddr     (araddr_cpu),
    .arlen      (arlen_cpu),
    .arsize     (arsize_cpu),
    .arburst    (arburst_cpu),
    .arlock     (arlock_cpu),
    .arcache    (arcache_cpu),
    .arprot     (arprot_cpu),
    .arvalid    (arvalid_cpu),
    .arready    (arready_cpu),
    
    .rid        (rid_cpu),
    .rdata      (rdata_cpu),
    .rresp      (rresp_cpu),
    .rlast      (rlast_cpu),
    .rvalid     (rvalid_cpu),
    .rready     (rready_cpu),
    
    .awid       (awid_cpu),
    .awaddr     (awaddr_cpu),
    .awlen      (awlen_cpu),
    .awsize     (awsize_cpu),
    .awburst    (awburst_cpu),
    .awlock     (awlock_cpu),
    .awcache    (awcache_cpu),
    .awprot     (awprot_cpu),
    .awvalid    (awvalid_cpu),
    .awready    (awready_cpu),
    
    .wid        (wid_cpu),
    .wdata      (wdata_cpu),
    .wstrb      (wstrb_cpu),
    .wlast      (wlast_cpu),
    .wvalid     (wvalid_cpu),
    .wready     (wready_cpu),
    
    .bid        (bid_cpu),
    .bresp      (bresp_cpu),
    .bvalid     (bvalid_cpu),
    .bready     (bready_cpu),
    
    .debug_wb_pc(), .debug_wb_rf_we(), .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

wire [ 3:0] arid_sram, arlen_sram, arcache_sram, awid_sram, awlen_sram, awcache_sram, wid_sram, wstrb_sram, rid_sram, bid_sram;
wire [31:0] araddr_sram, rdata_sram, awaddr_sram, wdata_sram;
wire [ 2:0] arsize_sram, arprot_sram, awsize_sram, awprot_sram;
wire [ 1:0] arburst_sram, arlock_sram, awburst_sram, awlock_sram, rresp_sram, bresp_sram;
wire arvalid_sram, arready_sram, rlast_sram, rvalid_sram, rready_sram;
wire awvalid_sram, awready_sram, wlast_sram, wvalid_sram, wready_sram;
wire bvalid_sram, bready_sram;

axi_cdc_wrapper #(
    .USE_CDC(0) // 1: 启用 IP 0: 直通不打拍
) u_axi_cdc_wrapper (
    // Slave 侧 (接 CPU)
    .s_axi_aclk    (clk_cpu),
    .s_axi_aresetn (cpu_resetn),
    .s_axi_arid    (arid_cpu),
    .s_axi_araddr  (araddr_cpu),
    .s_axi_arlen   (arlen_cpu),
    .s_axi_arsize  (arsize_cpu),
    .s_axi_arburst (arburst_cpu),
    .s_axi_arlock  (arlock_cpu),
    .s_axi_arcache (arcache_cpu),
    .s_axi_arprot  (arprot_cpu),
    .s_axi_arvalid (arvalid_cpu),
    .s_axi_arready (arready_cpu),
    .s_axi_rid     (rid_cpu),
    .s_axi_rdata   (rdata_cpu),
    .s_axi_rresp   (rresp_cpu),
    .s_axi_rlast   (rlast_cpu),
    .s_axi_rvalid  (rvalid_cpu),
    .s_axi_rready  (rready_cpu),
    .s_axi_awid    (awid_cpu),
    .s_axi_awaddr  (awaddr_cpu),
    .s_axi_awlen   (awlen_cpu),
    .s_axi_awsize  (awsize_cpu),
    .s_axi_awburst (awburst_cpu),
    .s_axi_awlock  (awlock_cpu),
    .s_axi_awcache (awcache_cpu),
    .s_axi_awprot  (awprot_cpu),  
    .s_axi_awvalid (awvalid_cpu),
    .s_axi_awready (awready_cpu),
    .s_axi_wdata   (wdata_cpu),
    .s_axi_wstrb   (wstrb_cpu),
    .s_axi_wlast   (wlast_cpu),
    .s_axi_wvalid  (wvalid_cpu),
    .s_axi_wready  (wready_cpu),
    .s_axi_bid     (bid_cpu),
    .s_axi_bresp   (bresp_cpu),
    .s_axi_bvalid  (bvalid_cpu),
    .s_axi_bready  (bready_cpu),

    // Master 侧 (接 SRAM/UART 外设状态机)
    .m_axi_aclk    (clk_sram),
    .m_axi_aresetn (sram_resetn),
    .m_axi_arid    (arid_sram),
    .m_axi_araddr  (araddr_sram),
    .m_axi_arlen   (arlen_sram),
    .m_axi_arsize  (arsize_sram),
    .m_axi_arburst (arburst_sram),
    .m_axi_arlock  (arlock_sram),
    .m_axi_arcache (arcache_sram),
    .m_axi_arprot  (arprot_sram),
    .m_axi_arvalid (arvalid_sram),
    .m_axi_arready (arready_sram),
    .m_axi_rid     (rid_sram),
    .m_axi_rdata   (rdata_sram),
    .m_axi_rresp   (rresp_sram),
    .m_axi_rlast   (rlast_sram),
    .m_axi_rvalid  (rvalid_sram),
    .m_axi_rready  (rready_sram),
    .m_axi_awid    (awid_sram),
    .m_axi_awaddr  (awaddr_sram),
    .m_axi_awlen   (awlen_sram),
    .m_axi_awsize  (awsize_sram),
    .m_axi_awburst (awburst_sram),
    .m_axi_awlock  (awlock_sram),
    .m_axi_awcache (awcache_sram), 
    .m_axi_awprot  (awprot_sram),
    .m_axi_awvalid (awvalid_sram),
    .m_axi_awready (awready_sram),
    .m_axi_wdata   (wdata_sram),
    .m_axi_wstrb   (wstrb_sram),
    .m_axi_wlast   (wlast_sram),
    .m_axi_wvalid  (wvalid_sram),
    .m_axi_wready  (wready_sram),
    .m_axi_bid     (bid_sram),
    .m_axi_bresp   (bresp_sram),
    .m_axi_bvalid  (bvalid_sram),
    .m_axi_bready  (bready_sram)
);

wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_buffer;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
reg  ext_uart_start, ext_uart_avai;

async_receiver #(.ClkFrequency(50000000), .Baud(115200)) ext_uart_r (
    .clk(clk_sram), 
    .RxD(rxd),
    .RxD_data_ready(ext_uart_ready),
    .RxD_clear(ext_uart_clear),
    .RxD_data(ext_uart_rx)
);

assign ext_uart_clear = ext_uart_ready; 
async_transmitter #(.ClkFrequency(50000000), .Baud(115200)) ext_uart_t (
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
                if (rvalid_sram && rready_sram && rlast_sram) slave_state <= S_IDLE;
            end
            S_WRITE: begin
                if (bvalid_sram && bready_sram) slave_state <= S_IDLE;
            end
        endcase
    end
end

wire is_read  = (slave_state == S_READ)  || (slave_state == S_IDLE && arvalid_sram);
wire is_write = (slave_state == S_WRITE) || (slave_state == S_IDLE && !arvalid_sram && (awvalid_sram || wvalid_sram));

reg rvalid_reg;
reg [31:0] raddr_reg;
reg [3:0]  rid_reg;
reg [7:0]  rlen_reg;
reg [1:0]  rburst_reg;
reg [7:0]  rbeat_cnt;

assign arready_sram = is_read && !rvalid_reg;
wire read_fire = arvalid_sram && arready_sram;

always @(posedge clk_sram) begin
    if (!sram_resetn) begin
        rvalid_reg <= 0;
        rbeat_cnt  <= 0;
    end else if (read_fire) begin
        rvalid_reg <= 1;
        raddr_reg  <= araddr_sram;
        rid_reg    <= arid_sram;
        rlen_reg   <= arlen_sram;
        rburst_reg <= arburst_sram;
        rbeat_cnt  <= 8'd0;
    end else if (rvalid_sram && rready_sram) begin
        if (rbeat_cnt == rlen_reg) begin
            rvalid_reg <= 0;
        end else begin
            rbeat_cnt <= rbeat_cnt + 8'd1;
            if (rburst_reg == 2'b10) begin
                raddr_reg <= {raddr_reg[31:5], raddr_reg[4:2] + 3'd1, 2'b00};
            end else begin
                raddr_reg <= raddr_reg + 32'd4;
            end
        end
    end
end

assign rvalid_sram = rvalid_reg;
assign rlast_sram  = (rbeat_cnt == rlen_reg);
assign rresp_sram  = 2'b0;
assign rid_sram    = rid_reg;

wire [31:0] current_raddr = read_fire ? araddr_sram : raddr_reg;

reg aw_recvd, w_recvd;
reg [31:0] awaddr_reg;
reg [31:0] wdata_reg;
reg [ 3:0] wstrb_reg;
reg [ 3:0] bid_reg;
reg bvalid_reg;

assign awready_sram = is_write && !aw_recvd && !bvalid_reg;
assign wready_sram  = is_write && !w_recvd  && !bvalid_reg;
wire aw_fire = awvalid_sram && awready_sram;
wire w_fire  = wvalid_sram && wready_sram;

always @(posedge clk_sram) begin
    if (!sram_resetn) begin
        aw_recvd <= 0;
        w_recvd <= 0;
        bvalid_reg <= 0;
    end else begin
        if (bvalid_sram && bready_sram) begin
            bvalid_reg <= 0;
        end
        
        if (aw_fire) begin
            aw_recvd <= 1;
            awaddr_reg <= awaddr_sram;
            bid_reg <= awid_sram;
        end
        if (w_fire) begin
            w_recvd <= 1;
            wdata_reg <= wdata_sram;
            wstrb_reg <= wstrb_sram;
        end
        
        if ((aw_recvd || aw_fire) && (w_recvd || w_fire) && !bvalid_reg) begin
            bvalid_reg <= 1;
            aw_recvd <= 0;
            w_recvd <= 0;
        end
    end
end

assign bvalid_sram = bvalid_reg;
assign bresp_sram  = 2'b0;
assign bid_sram    = bid_reg;

wire do_write = ((aw_recvd || aw_fire) && (w_recvd || w_fire) && !bvalid_reg);
wire [31:0] current_waddr = aw_fire ? awaddr_sram : awaddr_reg;
wire [31:0] current_wdata = w_fire ? wdata_sram : wdata_reg;
wire [ 3:0] current_wstrb = w_fire ? wstrb_sram : wstrb_reg;

wire [31:0] mem_addr = do_write ? current_waddr : current_raddr;
wire        mem_we   = do_write;
wire        mem_re   = rvalid_reg; 

wire is_base = (mem_addr[31:22] == 10'h070); 
wire is_ext  = (mem_addr[31:22] == 10'h071); 
wire is_uart = (mem_addr[31:20] == 12'h1f0); 

// BaseRAM
assign base_ram_ce_n = ~(is_base && (mem_re || mem_we));
assign base_ram_we_n = ~(is_base && mem_we);
assign base_ram_oe_n = ~(is_base && mem_re && !mem_we);
assign base_ram_be_n =  (is_base && mem_we) ? ~current_wstrb : 4'b0000;
assign base_ram_addr =  mem_addr[21:2];
assign base_ram_data =  (is_base && mem_we) ? current_wdata : 32'bz;

// ExtRAM
assign ext_ram_ce_n  = ~(is_ext && (mem_re || mem_we));
assign ext_ram_we_n  = ~(is_ext && mem_we);
assign ext_ram_oe_n  = ~(is_ext && mem_re && !mem_we);
assign ext_ram_be_n  =  (is_ext && mem_we) ? ~current_wstrb : 4'b0000;
assign ext_ram_addr  =  mem_addr[21:2];
assign ext_ram_data  =  (is_ext && mem_we) ? current_wdata : 32'bz;

reg uart_dlab;

always @(posedge clk_sram) begin
    if(!sram_resetn) begin
        ext_uart_start <= 0;
        ext_uart_tx    <= 0;
        uart_dlab      <= 0;
    end else begin
        if (is_uart && do_write && mem_addr[7:0] == 8'h03) begin
            uart_dlab <= current_wdata[7];
        end
        
        if (is_uart && do_write && mem_addr[7:0] == 8'h00 && !uart_dlab) begin
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