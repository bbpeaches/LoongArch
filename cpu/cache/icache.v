module icache (
    input         clk   ,   // 时钟
    input         resetn,   // 低有效复位信号

    // ==========================================
    // 类 SRAM 接口信号，用于 CPU 访问 Cache
    // ==========================================
    input         cpu_req      ,    // 由 CPU 发送至 Cache 
    input  [31:0] cpu_addr     ,    // 由 CPU 发送至 Cache 
    output [31:0] cache_rdata  ,    // 由 Cache 返回给 CPU 
    output        cache_addr_ok,    // 由 Cache 返回给 CPU 
    output        cache_data_ok,    // 由 Cache 返回给 CPU 

    // ==========================================
    // AXI 接口信号，用于 Cache 访问主存
    // ==========================================
    output [3 :0] arid   ,  // Cache 向主存发起读请求时使用的 AXI 信道的 id 号
    output [31:0] araddr ,  // Cache 向主存发起读请求时所使用的地址
    output        arvalid,  // Cache 向主存发起读请求的请求信号
    input         arready,  // 读请求能否被接收的握手信号
    
    input  [3 :0] rid    ,  // 主存向 Cache 返回数据时使用的 AXI 信道的 id 号
    input  [31:0] rdata  ,  // 主存向 Cache 返回的数据
    input         rlast  ,  // 是否是主存向 Cache 返回的最后一个数据
    input         rvalid ,  // 主存向 Cache 返回数据时的数据有效信号
    output        rready    // 标识当前的 Cache 已经准备好可以接收主存返回的数据
);

    // ==========================================
    // 状态机定义
    // ==========================================
    localparam IDLE   = 2'd0;
    localparam LOOKUP = 2'd1;
    localparam MISS   = 2'd2;
    localparam REFILL = 2'd3;

    reg [1:0] state, next_state;

    // ==========================================
    // 流水段 2 (LOOKUP) 寄存器
    // ==========================================
    reg        req_valid;
    reg [19:0] req_tag;
    reg [ 6:0] req_index;
    reg [ 4:0] req_offset;

    // ==========================================
    // LRU (最近最少使用) 替换记录表
    // lru_array[index] == 0 表示替换 Way0，== 1 表示替换 Way1
    // ==========================================
    reg [127:0] lru_array;
    reg         replace_way; // 在 MISS 时锁存需要替换的路

    // ==========================================
    // Cache 路 (Way) 连线定义
    // ==========================================
    wire [19:0] way0_r_tag, way1_r_tag;
    wire        way0_r_v,   way1_r_v;
    wire [255:0] way0_r_data, way1_r_data;

    wire way0_hit = way0_r_v && (way0_r_tag == req_tag);
    wire way1_hit = way1_r_v && (way1_r_tag == req_tag);
    wire cache_hit = way0_hit || way1_hit;

    // ==========================================
    // CPU 接口逻辑
    // ==========================================
    // 只要 Cache 处于空闲，或者在 LOOKUP 阶段且命中了，就可以接收新的请求
    assign cache_addr_ok = (state == IDLE) || (state == LOOKUP && cache_hit && req_valid);

    // 请求到达时，如果是 LOOKUP 命中且紧接着新的 cpu_req，可以直接无缝流转
    always @(posedge clk) begin
        if (~resetn) begin
            req_valid <= 1'b0;
        end else if (cache_addr_ok && cpu_req) begin
            req_valid <= 1'b1;        // 接收新请求
        end else if (cache_data_ok) begin
            req_valid <= 1'b0;        // 请求完成，且没有新请求到来时清空
        end
    end

    // 保存请求地址供第 2 级流水线和 MISS 状态使用
    always @(posedge clk) begin
        if (cache_addr_ok && cpu_req) begin
            req_tag    <= cpu_addr[31:12];
            req_index  <= cpu_addr[11:5];
            req_offset <= cpu_addr[4:0];
        end
    end

    // 数据选通：根据 Offset 取出命中路的 32位 字
    wire [31:0] way0_word = way0_r_data[ req_offset[4:2] * 32 +: 32 ];
    wire [31:0] way1_word = way1_r_data[ req_offset[4:2] * 32 +: 32 ];

    // 返回给 CPU 的数据：若是 Early Restart 则直接取 AXI 的 rdata，否则取命中的字
    assign cache_rdata = (state == REFILL) ? rdata :
                         (way0_hit)        ? way0_word :
                         (way1_hit)        ? way1_word : 32'd0;

    // ==========================================
    // LRU 替换状态更新
    // ==========================================
    always @(posedge clk) begin
        if (~resetn) begin
            lru_array <= 128'b0;
        end else if (state == LOOKUP && req_valid && cache_hit) begin
            // 命中了 Way0，下次就替换 Way1 (置1)；命中了 Way1，下次就替换 Way0 (置0)
            lru_array[req_index] <= way0_hit; 
        end
    end

    // MISS 时，锁定将要被牺牲的那一路
    always @(posedge clk) begin
        if (state == LOOKUP && req_valid && !cache_hit) begin
            replace_way <= lru_array[req_index];
        end
    end

    // ==========================================
    // AXI 读通道逻辑
    // ==========================================
    reg arvalid_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            arvalid_reg <= 1'b0;
        end else if (state == LOOKUP && req_valid && !cache_hit) begin
            arvalid_reg <= 1'b1; // 发起 MISS 读请求
        end else if (arvalid_reg && arready) begin
            arvalid_reg <= 1'b0; // 握手成功，撤销请求
        end
    end

    assign arid    = 4'd0;
    assign arvalid = arvalid_reg;
    // WRAP 模式的核心：起始地址直接设定为 CPU 请求的精确地址，使 AXI 第一个返回的字就是缺失字
    assign araddr  = {req_tag, req_index, req_offset[4:2], 2'b00};

    // AXI 接收准备信号
    assign rready  = (state == REFILL);

    // 突发传输字计数器 (0~7)
    reg [2:0] refill_cnt;
    always @(posedge clk) begin
        if (~resetn) begin
            refill_cnt <= 3'd0;
        end else if (state == REFILL && rvalid && rready) begin
            refill_cnt <= refill_cnt + 3'd1;
        end else if (state != REFILL) begin
            refill_cnt <= 3'd0;
        end
    end

    // 尽早重启动 (Early Restart)：在 REFILL 的第一拍直接把关键字给 CPU
    assign cache_data_ok = (state == LOOKUP && req_valid && cache_hit) ||
                           (state == REFILL && rvalid && rready && (refill_cnt == 3'd0));

    // ==========================================
    // Cache RAM 写控制逻辑 (REFILL 阶段)
    // ==========================================
    // WRAP 模式回环写入 Bank 计算：起始 offset 加上计数值即可自然溢出回环 (3bit加法)
    wire [2:0] current_bank = req_offset[4:2] + refill_cnt;
    wire [7:0] w_bank_en    = (state == REFILL && rvalid && rready) ? (8'b1 << current_bank) : 8'd0;
    
    // Tag 和 Valid 仅在突发传输最后一个字到达时写入
    wire w_tag_v_en = (state == REFILL && rvalid && rready && rlast);

    // ==========================================
    // 实例化双路 Cache Way
    // ==========================================
    // Way 0
    cache_way way0 (
        .clk         (clk),
        .resetn      (resetn),
        // 读端口 (第 1 级流水线)
        .r_en        (cache_addr_ok && cpu_req),
        .r_index     (cpu_addr[11:5]),
        .r_tag_out   (way0_r_tag),
        .r_v_out     (way0_r_v),
        .r_data_out  (way0_r_data),
        // 写端口 (REFILL 阶段)
        .w_tag_v_en  (w_tag_v_en && (replace_way == 1'b0)),
        .w_index     (req_index),
        .w_tag       (req_tag),
        .w_v         (1'b1),
        .w_bank_en   ((replace_way == 1'b0) ? w_bank_en : 8'd0),
        .w_bank_data (rdata)
    );

    // Way 1
    cache_way way1 (
        .clk         (clk),
        .resetn      (resetn),
        // 读端口 (第 1 级流水线)
        .r_en        (cache_addr_ok && cpu_req),
        .r_index     (cpu_addr[11:5]),
        .r_tag_out   (way1_r_tag),
        .r_v_out     (way1_r_v),
        .r_data_out  (way1_r_data),
        // 写端口 (REFILL 阶段)
        .w_tag_v_en  (w_tag_v_en && (replace_way == 1'b1)),
        .w_index     (req_index),
        .w_tag       (req_tag),
        .w_v         (1'b1),
        .w_bank_en   ((replace_way == 1'b1) ? w_bank_en : 8'd0),
        .w_bank_data (rdata)
    );

    // ==========================================
    // 核心主状态机 (FSM)
    // ==========================================
    always @(posedge clk) begin
        if (~resetn) state <= IDLE;
        else         state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                // 有请求且允许接收，进入查表阶段
                if (cpu_req && cache_addr_ok)
                    next_state = LOOKUP;
            end
            LOOKUP: begin
                if (req_valid) begin
                    if (cache_hit) begin
                        // 命中时，若有背靠背新请求，维持 LOOKUP 流水线；否则回 IDLE
                        if (cpu_req && cache_addr_ok)
                            next_state = LOOKUP;
                        else
                            next_state = IDLE;
                    end else begin
                        // 未命中，去外存捞数据
                        next_state = MISS;
                    end
                end else begin
                    // 处理由于 Flush 或异常导致的空泡情况
                    if (cpu_req && cache_addr_ok)
                        next_state = LOOKUP;
                    else
                        next_state = IDLE;
                end
            end
            MISS: begin
                // 地址通道握手成功，准备接收数据
                if (arvalid_reg && arready)
                    next_state = REFILL;
            end
            REFILL: begin
                // 突发传输完成 (rlast = 1)，填满整条 Cache Line，回 IDLE 准备下一周期响应 CPU
                if (rvalid && rready && rlast)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule