module thinpad_top(
    input wire clk_50M,           // 50MHz 时钟输入
    input wire clk_11M0592,       // 11.0592MHz 时钟输入（备用，可不用）
    input wire clock_btn,         // BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         // BTN6手动复位按钮开关，带消抖电路，按下时为1
    input  wire[3:0]  touch_btn,  // BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,     // 32位拨码开关，拨到“ON”时为1
    output wire[15:0] leds,       // 16位LED，输出时1点亮
    output wire[7:0]  dpy0,       // 数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       // 数码管高位信号，包括小数点，输出1点亮

    // BaseRAM信号
    inout wire[31:0] base_ram_data,  
    output wire[19:0] base_ram_addr, 
    output wire[3:0] base_ram_be_n,  
    output wire base_ram_ce_n,       
    output wire base_ram_oe_n,       
    output wire base_ram_we_n,       

    // ExtRAM信号
    inout wire[31:0] ext_ram_data,  
    output wire[19:0] ext_ram_addr, 
    output wire[3:0] ext_ram_be_n,  
    output wire ext_ram_ce_n,       
    output wire ext_ram_oe_n,       
    output wire ext_ram_we_n,       

    // 直连串口信号
    output wire txd,  
    input  wire rxd,  

    // Flash存储器信号
    output wire [22:0]flash_a,      
    inout  wire [15:0]flash_d,      
    output wire flash_rp_n,         
    output wire flash_vpen,         
    output wire flash_ce_n,         
    output wire flash_oe_n,         
    output wire flash_we_n,         
    output wire flash_byte_n,       

    // 图像输出信号
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
// 1. 时钟与复位生成
// ----------------------------------------
wire locked, clk_10M, clk_20M;
pll_example clock_gen (
  .clk_in1(clk_50M),
  .clk_out1(clk_10M), // 统一降频到10M，确保纯组合逻辑乘法器和SRAM时序充裕
  .clk_out2(clk_20M),
  .reset(reset_btn),
  .locked(locked)
);

reg reset_of_clk10M;
always@(posedge clk_10M or negedge locked) begin
    if(~locked) reset_of_clk10M <= 1'b1;
    else        reset_of_clk10M <= 1'b0;
end
wire cpu_resetn = ~reset_of_clk10M;

// ----------------------------------------
// 2. 串口收发控制器 (修改波特率为115200, 时钟为10M)
// ----------------------------------------
wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_buffer;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
reg  ext_uart_start, ext_uart_avai;

async_receiver #(.ClkFrequency(10000000), .Baud(115200)) ext_uart_r (
    .clk(clk_10M), 
    .RxD(rxd),
    .RxD_data_ready(ext_uart_ready),
    .RxD_clear(ext_uart_clear),
    .RxD_data(ext_uart_rx)
);
assign ext_uart_clear = ext_uart_ready; 

async_transmitter #(.ClkFrequency(10000000), .Baud(115200)) ext_uart_t (
    .clk(clk_10M), 
    .TxD(txd),
    .TxD_busy(ext_uart_busy),
    .TxD_start(ext_uart_start),
    .TxD_data(ext_uart_tx)
);

// ----------------------------------------
// 3. 例化你的 CPU
// ----------------------------------------
wire        cpu_inst_en;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_rdata;
wire        cpu_inst_wait; 

wire        cpu_data_en;
wire [ 3:0] cpu_data_wen;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
reg  [31:0] cpu_data_rdata;

cpu u_cpu (
    .clk                  (clk_10M), 
    .resetn               (cpu_resetn),
    .inst_sram_wait       (cpu_inst_wait), // 新增的用于阻塞取指的信号

    .inst_sram_en         (cpu_inst_en),
    .inst_sram_addr       (cpu_inst_addr),
    .inst_sram_rdata      (cpu_inst_rdata),

    .data_sram_en         (cpu_data_en),
    .data_sram_wen        (cpu_data_wen),
    .data_sram_addr       (cpu_data_addr),
    .data_sram_wdata      (cpu_data_wdata),
    .data_sram_rdata      (cpu_data_rdata),
    .data_sram_resp_valid (cpu_data_en),   // 单周期同步返回
    
    // Debug 悬空即可
    .debug_wb_pc(), .debug_wb_rf_wen(), .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

// ----------------------------------------
// 4. 地址译码与仲裁
// ----------------------------------------
// 数据空间译码
wire data_is_base = (cpu_data_addr[31:22] == 10'h070); // 0x1c000000
wire data_is_ext  = (cpu_data_addr[31:22] == 10'h071); // 0x1c400000
wire data_is_uart = (cpu_data_addr[31:20] == 12'h1f0); // 0x1f000000

// 指令空间译码
wire inst_is_base = (cpu_inst_addr[31:22] == 10'h070); 
wire inst_is_ext  = (cpu_inst_addr[31:22] == 10'h071); 

// 冲突仲裁：当数据和指令同时访问同一个物理RAM时，数据优先，指令挂起等待
wire conflict_base = (cpu_data_en && data_is_base) && (cpu_inst_en && inst_is_base);
wire conflict_ext  = (cpu_data_en && data_is_ext)  && (cpu_inst_en && inst_is_ext);
assign cpu_inst_wait = conflict_base || conflict_ext; 

// 仲裁后的指令放行许可
wire inst_base_ack = (cpu_inst_en && inst_is_base) && !conflict_base;
wire inst_ext_ack  = (cpu_inst_en && inst_is_ext)  && !conflict_ext;

// BaseRAM 控制信号合成
assign base_ram_ce_n = ~((cpu_data_en && data_is_base) || inst_base_ack);
assign base_ram_we_n = ~((cpu_data_en && data_is_base) && (cpu_data_wen != 4'b0000));
assign base_ram_oe_n = ~(((cpu_data_en && data_is_base) && (cpu_data_wen == 4'b0000)) || inst_base_ack);
assign base_ram_be_n =  (cpu_data_en && data_is_base) ? ~cpu_data_wen : 4'b0000;
assign base_ram_addr =  (cpu_data_en && data_is_base) ? cpu_data_addr[21:2] : cpu_inst_addr[21:2];
assign base_ram_data = ((cpu_data_en && data_is_base) && (cpu_data_wen != 4'b0000)) ? cpu_data_wdata : 32'bz;

// ExtRAM 控制信号合成
assign ext_ram_ce_n  = ~((cpu_data_en && data_is_ext) || inst_ext_ack);
assign ext_ram_we_n  = ~((cpu_data_en && data_is_ext) && (cpu_data_wen != 4'b0000));
assign ext_ram_oe_n  = ~(((cpu_data_en && data_is_ext) && (cpu_data_wen == 4'b0000)) || inst_ext_ack);
assign ext_ram_be_n  =  (cpu_data_en && data_is_ext) ? ~cpu_data_wen : 4'b0000;
assign ext_ram_addr  =  (cpu_data_en && data_is_ext) ? cpu_data_addr[21:2] : cpu_inst_addr[21:2];
assign ext_ram_data  = ((cpu_data_en && data_is_ext) && (cpu_data_wen != 4'b0000)) ? cpu_data_wdata : 32'bz;

// 指令读取数据 MUX 返回给 CPU
assign cpu_inst_rdata = inst_base_ack ? base_ram_data : 
                        inst_ext_ack  ? ext_ram_data  : 32'd0;

// ----------------------------------------
// 5. MMIO 串口逻辑处理
// ----------------------------------------
// CPU 写入 UART 数据 (0x1f000000)
always @(posedge clk_10M) begin
    if(reset_of_clk10M) begin
        ext_uart_start <= 0;
        ext_uart_tx    <= 0;
    end else begin
        if (cpu_data_en && data_is_uart && (cpu_data_wen != 0) && cpu_data_addr[7:0] == 8'h00) begin
            ext_uart_tx    <= cpu_data_wdata[7:0];
            ext_uart_start <= 1;
        end else begin
            ext_uart_start <= 0;
        end
    end
end

// CPU 读取 UART 及状态清零
always @(posedge clk_10M) begin
    if(reset_of_clk10M) begin
        ext_uart_avai   <= 0;
        ext_uart_buffer <= 0;
    end else begin
        if (ext_uart_ready) begin
            ext_uart_buffer <= ext_uart_rx;
            ext_uart_avai   <= 1;
        // 当CPU发出读请求且地址为数据寄存器时，清空“可用”标志位
        end else if (cpu_data_en && data_is_uart && (cpu_data_wen == 0) && cpu_data_addr[7:0] == 8'h00) begin
            ext_uart_avai   <= 0; 
        end
    end
end

// 数据读取数据 MUX (RAM 与 MMIO) 返回给 CPU
always @(*) begin
    cpu_data_rdata = 32'd0;
    if (cpu_data_en && data_is_base) begin
        cpu_data_rdata = base_ram_data;
    end else if (cpu_data_en && data_is_ext) begin
        cpu_data_rdata = ext_ram_data;
    end else if (cpu_data_en && data_is_uart) begin
        if (cpu_data_addr[7:0] == 8'h05)      // 读 UART_STATUS
            cpu_data_rdata = {26'd0, !ext_uart_busy, 4'd0, ext_uart_avai}; // Bit5=TX_RDY, Bit0=RX_RDY
        else if (cpu_data_addr[7:0] == 8'h00) // 读 UART_DATA
            cpu_data_rdata = {24'd0, ext_uart_buffer};
    end
end

// ----------------------------------------
// 6. 其他外设禁用及默认设置
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
