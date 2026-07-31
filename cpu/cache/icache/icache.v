module icache (
    input  wire        clk   ,   // 时钟
    input  wire        resetn,   // 低有效复位信号

    input  wire        cpu_req      ,    // 由 CPU 发送至 Cache
    input  wire [31:0] cpu_addr     ,    // 由 CPU 发送至 Cache
    output wire [31:0] cache_rdata  ,    // 由 Cache 返回给 CPU
    output wire        cache_addr_ok,    // 由 Cache 返回给 CPU
    output wire        cache_data_ok,    // 由 Cache 返回给 CPU

    output wire [3 :0] arid   ,  // Cache 向主存发起读请求时使用的 AXI 信道的 id 号
    output wire [31:0] araddr ,  // Cache 向主存发起读请求时所使用的地址
    output wire        arvalid,  // Cache 向主存发起读请求的请求信号
    input  wire        arready,  // 读请求能否被接收的握手信号
    
    input  wire [3 :0] rid    ,  // 主存向 Cache 返回数据时使用的 AXI 信道的 id 号
    input  wire [31:0] rdata  ,  // 主存向 Cache 返回的数据
    input  wire        rlast  ,  // 是否是主存向 Cache 返回的最后一个数据
    input  wire        rvalid ,  // 主存向 Cache 返回数据时的数据有效信号
    output wire        rready    // 标识当前的 Cache 已经准备好可以接收主存返回的数据
);

    localparam IDLE   = 2'd0;
    localparam LOOKUP = 2'd1;
    localparam MISS   = 2'd2;
    localparam REFILL = 2'd3;

    reg [1:0] state, next_state;
    reg [2:0] refill_cnt;

    reg        req_valid;
    reg [19:0] req_tag;
    reg [ 6:0] req_index;
    reg [ 4:0] req_offset;

    reg [19:0] refill_tag;
    reg [ 6:0] refill_index;
    reg [ 4:0] refill_offset;

    reg [127:0] lru_array;
    reg         replace_way; 

    wire [19:0] way0_r_tag, way1_r_tag;
    wire        way0_r_v,   way1_r_v;
    wire [255:0] way0_r_data, way1_r_data;

    wire way0_hit = way0_r_v && (way0_r_tag == req_tag);
    wire way1_hit = way1_r_v && (way1_r_tag == req_tag);
    wire cache_hit = way0_hit || way1_hit;

    wire [2:0] current_bank = refill_offset[4:2] + refill_cnt;
    wire bypass_match = (state == REFILL) && req_valid &&
                        (req_tag == refill_tag) &&
                        (req_index == refill_index) &&
                        (req_offset[4:2] == current_bank);

    assign cache_addr_ok = (state == IDLE) || 
                           (state == LOOKUP && cache_hit && req_valid) ||
                           (state == REFILL && (!req_valid || cache_data_ok));

    wire next_req_valid = (cache_addr_ok && cpu_req) ? 1'b1 :
                          (cache_data_ok) ? 1'b0 : req_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            req_valid <= 1'b0;
        end else if (cache_addr_ok && cpu_req) begin
            req_valid <= 1'b1;        
        end else if (cache_data_ok) begin
            req_valid <= 1'b0;        
        end
    end

    always @(posedge clk) begin
        if (cache_addr_ok && cpu_req) begin
            req_tag    <= cpu_addr[31:12];
            req_index  <= cpu_addr[11:5];
            req_offset <= cpu_addr[4:0];
        end
    end

    always @(posedge clk) begin
        if (state == LOOKUP && req_valid && !cache_hit) begin
            refill_tag    <= req_tag;
            refill_index  <= req_index;
            refill_offset <= req_offset;
        end
    end

    wire [31:0] way0_word = way0_r_data[ req_offset[4:2] * 32 +: 32 ];
    wire [31:0] way1_word = way1_r_data[ req_offset[4:2] * 32 +: 32 ];

    assign cache_rdata = (bypass_match) ? rdata :
                         (way0_hit)     ? way0_word :
                         (way1_hit)     ? way1_word : 32'd0;

    always @(posedge clk) begin
        if (~resetn) begin
            lru_array <= 128'b0;
        end else if (state == LOOKUP && req_valid && cache_hit) begin
            lru_array[req_index] <= way0_hit; 
        end
    end

    always @(posedge clk) begin
        if (state == LOOKUP && req_valid && !cache_hit) begin
            replace_way <= lru_array[req_index];
        end
    end

    reg arvalid_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            arvalid_reg <= 1'b0;
        end else if (state == LOOKUP && req_valid && !cache_hit) begin
            arvalid_reg <= 1'b1; 
        end else if (arvalid_reg && arready) begin
            arvalid_reg <= 1'b0; 
        end
    end

    assign arid    = 4'd0;
    assign arvalid = arvalid_reg;
    assign araddr  = {refill_tag, refill_index, refill_offset[4:2], 2'b00};

    assign rready  = (state == REFILL);

    always @(posedge clk) begin
        if (~resetn) begin
            refill_cnt <= 3'd0;
        end else if (state == REFILL && rvalid && rready) begin
            refill_cnt <= refill_cnt + 3'd1;
        end else if (state != REFILL) begin
            refill_cnt <= 3'd0;
        end
    end

    assign cache_data_ok = (state == LOOKUP && req_valid && cache_hit) ||
                           (bypass_match && rvalid && rready);

    wire [7:0] w_bank_en    = (state == REFILL && rvalid && rready) ? (8'b1 << current_bank) : 8'd0;
    wire w_tag_v_en = (state == REFILL && rvalid && rready && rlast);

    // Way 0
    icache_way way0 (
        .clk         (clk),
        .resetn      (resetn),
        .r_en        (cache_addr_ok),
        .r_index     (cpu_addr[11:5]),
        .r_tag_out   (way0_r_tag),
        .r_v_out     (way0_r_v),
        .r_data_out  (way0_r_data),
        .w_tag_v_en  (w_tag_v_en && (replace_way == 1'b0)),
        .w_index     (refill_index), 
        .w_tag       (refill_tag), 
        .w_v         (1'b1),
        .w_bank_en   ((replace_way == 1'b0) ? w_bank_en : 8'd0),
        .w_bank_data (rdata)
    );

    // Way 1
    icache_way way1 (
        .clk         (clk),
        .resetn      (resetn),
        .r_en        (cache_addr_ok),
        .r_index     (cpu_addr[11:5]),
        .r_tag_out   (way1_r_tag),
        .r_v_out     (way1_r_v),
        .r_data_out  (way1_r_data),
        .w_tag_v_en  (w_tag_v_en && (replace_way == 1'b1)),
        .w_index     (refill_index), 
        .w_tag       (refill_tag),  
        .w_v         (1'b1),
        .w_bank_en   ((replace_way == 1'b1) ? w_bank_en : 8'd0),
        .w_bank_data (rdata)
    );

    always @(posedge clk) begin
        if (~resetn) state <= IDLE;
        else         state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (cpu_req && cache_addr_ok)
                    next_state = LOOKUP;
            end
            LOOKUP: begin
                if (req_valid) begin
                    if (cache_hit) begin
                        if (cpu_req && cache_addr_ok)
                            next_state = LOOKUP;
                        else
                            next_state = IDLE;
                    end else begin
                        next_state = MISS;
                    end
                end else begin
                    if (cpu_req && cache_addr_ok)
                        next_state = LOOKUP;
                    else
                        next_state = IDLE;
                end
            end
            MISS: begin
                if (arvalid_reg && arready)
                    next_state = REFILL;
            end
            REFILL: begin
                if (rvalid && rready && rlast) begin
                    if (next_req_valid)
                        next_state = LOOKUP;
                    else
                        next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule