module thinpad_top(
    input wire clk_50M,           // 50MHz ʱ������
    input wire clk_11M0592,       // 11.0592MHz ʱ�����루���ã��ɲ��ã�
    input wire clock_btn,         // BTN5�ֶ�ʱ�Ӱ�ť���أ���������·������ʱΪ1
    input wire reset_btn,         // BTN6�ֶ���λ��ť���أ���������·������ʱΪ1
    input  wire[3:0]  touch_btn,  // BTN1~BTN4����ť���أ�����ʱΪ1
    input  wire[31:0] dip_sw,     // 32λ���뿪�أ�������ON��ʱΪ1
    output wire[15:0] leds,       // 16λLED�����ʱ1����
    output wire[7:0]  dpy0,       // ����ܵ�λ�źţ�����С���㣬���1����
    output wire[7:0]  dpy1,       // ����ܸ�λ�źţ�����С���㣬���1����

    // BaseRAM�ź�
    inout wire[31:0] base_ram_data,  
    output wire[19:0] base_ram_addr, 
    output wire[3:0] base_ram_be_n,  
    output wire base_ram_ce_n,       
    output wire base_ram_oe_n,       
    output wire base_ram_we_n,       

    // ExtRAM�ź�
    inout wire[31:0] ext_ram_data,  
    output wire[19:0] ext_ram_addr, 
    output wire[3:0] ext_ram_be_n,  
    output wire ext_ram_ce_n,       
    output wire ext_ram_oe_n,       
    output wire ext_ram_we_n,       

    // ֱ�������ź�
    output wire txd,  
    input  wire rxd,  

    // Flash�洢���ź�
    output wire [22:0]flash_a,      
    inout  wire [15:0]flash_d,      
    output wire flash_rp_n,         
    output wire flash_vpen,         
    output wire flash_ce_n,         
    output wire flash_oe_n,         
    output wire flash_we_n,         
    output wire flash_byte_n,       

    // ͼ������ź�
    output wire[2:0] video_red,    
    output wire[2:0] video_green,  
    output wire[1:0] video_blue,   
    output wire video_hsync,       
    output wire video_vsync,       
    output wire video_clk,         
    output wire video_de           
);

/* =========== Core Logic Begin =========== */

// ----------------------------------------
// 1. ʱ���븴λ����
// ----------------------------------------
wire locked, clk_My, clk_20M;
pll_example clock_gen (
  .clk_in1(clk_50M),
  .clk_out1(clk_My), 
  .clk_out2(clk_20M),
  .reset(reset_btn),
  .locked(locked)
);

reg reset_of_clk10M;
always@(posedge clk_My or negedge locked) begin
    if(~locked) reset_of_clk10M <= 1'b1;
    else        reset_of_clk10M <= 1'b0;
end
wire cpu_resetn = ~reset_of_clk10M;

// ----------------------------------------
// 2. �����շ������� 
// ----------------------------------------
wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_buffer;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
reg  ext_uart_start, ext_uart_avai;

async_receiver #(.ClkFrequency(55000000), .Baud(115200)) ext_uart_r (
    .clk(clk_My), 
    .RxD(rxd),
    .RxD_data_ready(ext_uart_ready),
    .RxD_clear(ext_uart_clear),
    .RxD_data(ext_uart_rx)
);

assign ext_uart_clear = ext_uart_ready; 
async_transmitter #(.ClkFrequency(55000000), .Baud(115200)) ext_uart_t (
    .clk(clk_My), 
    .TxD(txd),
    .TxD_busy(ext_uart_busy),
    .TxD_start(ext_uart_start),
    .TxD_data(ext_uart_tx)
);

// ----------------------------------------
// 3. ���� AXI �ӿ� CPU (mycpu_top)
// ----------------------------------------
wire [ 3:0] arid, arlen, arcache, awid, awlen, awcache, wid, wstrb, rid, bid;
wire [31:0] araddr, rdata, awaddr, wdata;
wire [ 2:0] arsize, arprot, awsize, awprot;
wire [ 1:0] arburst, arlock, awburst, awlock, rresp, bresp;
wire arvalid, arready, rlast, rvalid, rready;
wire awvalid, awready, wlast, wvalid, wready;
wire bvalid, bready;

mycpu_top u_cpu (
    .aclk       (clk_My),
    .aresetn    (cpu_resetn),
    
    .arid       (arid),
    .araddr     (araddr),
    .arlen      (arlen),
    .arsize     (arsize),
    .arburst    (arburst),
    .arlock     (arlock),
    .arcache    (arcache),
    .arprot     (arprot),
    .arvalid    (arvalid),
    .arready    (arready),
    
    .rid        (rid),
    .rdata      (rdata),
    .rresp      (rresp),
    .rlast      (rlast),
    .rvalid     (rvalid),
    .rready     (rready),
    
    .awid       (awid),
    .awaddr     (awaddr),
    .awlen      (awlen),
    .awsize     (awsize),
    .awburst    (awburst),
    .awlock     (awlock),
    .awcache    (awcache),
    .awprot     (awprot),
    .awvalid    (awvalid),
    .awready    (awready),
    
    .wid        (wid),
    .wdata      (wdata),
    .wstrb      (wstrb),
    .wlast      (wlast),
    .wvalid     (wvalid),
    .wready     (wready),
    
    .bid        (bid),
    .bresp      (bresp),
    .bvalid     (bvalid),
    .bready     (bready),
    
    .debug_wb_pc(), .debug_wb_rf_we(), .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

// ----------------------------------------
// 4. AXI �ӻ�ת���߼� (�� AXI תΪ SRAM ʱ��)
// ----------------------------------------

// --- ��д����״̬�� (�������˿� SRAM) ---
reg [1:0] slave_state;
localparam S_IDLE  = 2'd0;
localparam S_READ  = 2'd1;
localparam S_WRITE = 2'd2;

always @(posedge clk_My) begin
    if (!cpu_resetn) begin
        slave_state <= S_IDLE;
    end else begin
        case (slave_state)
            S_IDLE: begin
                if (arvalid) slave_state <= S_READ;
                else if (awvalid || wvalid) slave_state <= S_WRITE;
            end
            S_READ: begin
                if (rvalid && rready && rlast) slave_state <= S_IDLE;
            end
            S_WRITE: begin
                if (bvalid && bready) slave_state <= S_IDLE;
            end
        endcase
    end
end

wire is_read  = (slave_state == S_READ)  || (slave_state == S_IDLE && arvalid);
wire is_write = (slave_state == S_WRITE) || (slave_state == S_IDLE && !arvalid && (awvalid || wvalid));

// --- ��ͨ�� (AR & R) ֧�� Burst ---
reg rvalid_reg;
reg [31:0] raddr_reg;
reg [3:0]  rid_reg;
reg [7:0]  rlen_reg;
reg [1:0]  rburst_reg;
reg [7:0]  rbeat_cnt;

assign arready = is_read && !rvalid_reg;
wire read_fire = arvalid && arready;

always @(posedge clk_My) begin
    if (!cpu_resetn) begin
        rvalid_reg <= 0;
        rbeat_cnt  <= 0;
    end else if (read_fire) begin
        rvalid_reg <= 1;
        raddr_reg  <= araddr;
        rid_reg    <= arid;
        rlen_reg   <= arlen;
        rburst_reg <= arburst;
        rbeat_cnt  <= 8'd0;
    end else if (rvalid && rready) begin
        if (rbeat_cnt == rlen_reg) begin
            rvalid_reg <= 0;
        end else begin
            rbeat_cnt <= rbeat_cnt + 8'd1;
            if (rburst_reg == 2'b10) begin
                // WRAP ģʽ���� 32 �ֽڱ߽��ڻػ� (��Ӧλ [4:2])
                raddr_reg <= {raddr_reg[31:5], raddr_reg[4:2] + 3'd1, 2'b00};
            end else begin
                // INCR ģʽ (���� Data SRAM ��)��˳���ۼ� 4
                raddr_reg <= raddr_reg + 32'd4;
            end
        end
    end
end

assign rvalid = rvalid_reg;
assign rlast  = (rbeat_cnt == rlen_reg);
assign rresp  = 2'b0;
assign rid    = rid_reg;

wire [31:0] current_raddr = read_fire ? araddr : raddr_reg;

// --- дͨ�� (AW, W & B) ---
reg aw_recvd, w_recvd;
reg [31:0] awaddr_reg;
reg [31:0] wdata_reg;
reg [ 3:0] wstrb_reg;
reg [ 3:0] bid_reg;
reg bvalid_reg;

assign awready = is_write && !aw_recvd && !bvalid_reg;
assign wready  = is_write && !w_recvd  && !bvalid_reg;
wire aw_fire = awvalid && awready;
wire w_fire  = wvalid && wready;

always @(posedge clk_My) begin
    if (!cpu_resetn) begin
        aw_recvd <= 0;
        w_recvd <= 0;
        bvalid_reg <= 0;
    end else begin
        if (bvalid && bready) begin
            bvalid_reg <= 0;
        end
        
        if (aw_fire) begin
            aw_recvd <= 1;
            awaddr_reg <= awaddr;
            bid_reg <= awid;
        end
        if (w_fire) begin
            w_recvd <= 1;
            wdata_reg <= wdata;
            wstrb_reg <= wstrb;
        end
        
        if ((aw_recvd || aw_fire) && (w_recvd || w_fire) && !bvalid_reg) begin
            bvalid_reg <= 1;
            aw_recvd <= 0;
            w_recvd <= 0;
        end
    end
end

assign bvalid = bvalid_reg;
assign bresp  = 2'b0;
assign bid    = bid_reg;

wire do_write = ((aw_recvd || aw_fire) && (w_recvd || w_fire) && !bvalid_reg);
wire [31:0] current_waddr = aw_fire ? awaddr : awaddr_reg;
wire [31:0] current_wdata = w_fire ? wdata : wdata_reg;
wire [ 3:0] current_wstrb = w_fire ? wstrb : wstrb_reg;

// ----------------------------------------
// 5. �ڴ�ͳһ·�������� SRAM ����
// ----------------------------------------
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

// ----------------------------------------
// 6. MMIO �����߼�����
// ----------------------------------------
reg uart_dlab;

always @(posedge clk_My) begin
    if(reset_of_clk10M) begin
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

always @(posedge clk_My) begin
    if(reset_of_clk10M) begin
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

// �����ݷ�������
assign rdata = is_base ? base_ram_data :
               is_ext  ? ext_ram_data  :
               is_uart ? (
                   (mem_addr[7:2] == 6'h01) ? {4{uart_status}} : 
                   (mem_addr[7:2] == 6'h00) ? {24'd0, ext_uart_buffer} : 32'd0
               ) : 32'd0;

// ----------------------------------------
// 7. ����������ü�Ĭ������
// ----------------------------------------
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

/* =========== Core Logic End =========== */

endmodule