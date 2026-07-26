module write_buffer #(
    parameter DEPTH = 4
)(
    input  wire        clk,
    input  wire        resetn,

    // ==========================================
    // CPU 端接口 (Slave)
    // ==========================================
    input  wire        cpu_req,
    input  wire        cpu_wr,
    input  wire [ 1:0] cpu_size,
    input  wire [31:0] cpu_addr,
    input  wire [ 3:0] cpu_wstrb,
    input  wire [31:0] cpu_wdata,
    output wire        cpu_addr_ok,
    output wire        cpu_data_ok,
    output wire [31:0] cpu_rdata,

    // ==========================================
    // Memory/AXI 桥端接口 (Master)
    // ==========================================
    output wire        mem_req,
    output wire        mem_wr,
    output wire [ 1:0] mem_size,
    output wire [31:0] mem_addr,
    output wire [ 3:0] mem_wstrb,
    output wire [31:0] mem_wdata,
    input  wire        mem_addr_ok,
    input  wire        mem_data_ok,
    input  wire [31:0] mem_rdata
);

    // ------------------------------------
    // 写队列 (FIFO) 定义
    // ------------------------------------
    reg [31:0] buf_addr  [0:DEPTH-1];
    reg [31:0] buf_wdata [0:DEPTH-1];
    reg [ 3:0] buf_wstrb [0:DEPTH-1];
    reg [ 1:0] buf_size  [0:DEPTH-1];
    reg        buf_valid [0:DEPTH-1];

    reg [1:0] head;
    reg [1:0] tail;
    reg [2:0] count;

    wire buf_full  = (count == DEPTH);
    wire buf_empty = (count == 0);

    // ------------------------------------
    // 冲突检测 (RAW Hazard)
    // 为了安全和简单，只要同字地址重叠即认定为冲突，读操作需等待写回。
    // ------------------------------------
    wire conflict_0 = buf_valid[0] && (buf_addr[0][31:2] == cpu_addr[31:2]);
    wire conflict_1 = buf_valid[1] && (buf_addr[1][31:2] == cpu_addr[31:2]);
    wire conflict_2 = buf_valid[2] && (buf_addr[2][31:2] == cpu_addr[31:2]);
    wire conflict_3 = buf_valid[3] && (buf_addr[3][31:2] == cpu_addr[31:2]);
    wire has_conflict = conflict_0 | conflict_1 | conflict_2 | conflict_3;

    // ------------------------------------
    // CPU 请求分流与判定
    // ------------------------------------
    wire load_req  = cpu_req && !cpu_wr;
    wire store_req = cpu_req && cpu_wr;

    wire load_ready_to_go  = load_req && !has_conflict;
    wire store_ready_to_go = !buf_empty;

    // ------------------------------------
    // Memory 总线控制状态机
    // ------------------------------------
    localparam S_IDLE     = 2'd0;
    localparam S_DO_LOAD  = 2'd1;
    localparam S_DO_STORE = 2'd2;

    reg [1:0] state;

    always @(posedge clk) begin
        if (~resetn) begin
            state <= S_IDLE;
        end else case (state)
            S_IDLE: begin
                if (load_ready_to_go) begin // 读优先原则
                    if (mem_req && mem_addr_ok && mem_data_ok)
                        state <= S_IDLE;
                    else if (mem_req && mem_addr_ok)
                        state <= S_DO_LOAD;
                    else
                        state <= S_DO_LOAD;
                end else if (store_ready_to_go) begin // 队列有存货，向内存排空
                    if (mem_req && mem_addr_ok && mem_data_ok)
                        state <= S_IDLE;
                    else if (mem_req && mem_addr_ok)
                        state <= S_DO_STORE;
                    else
                        state <= S_DO_STORE;
                end
            end
            S_DO_LOAD: begin
                if (mem_data_ok) state <= S_IDLE;
            end
            S_DO_STORE: begin
                if (mem_data_ok) state <= S_IDLE;
            end
            default: state <= S_IDLE;
        endcase
    end

    // 锁存 Load 的请求地址和体积 (防止流水线清空时发出错乱地址)
    reg [31:0] load_addr_latch;
    reg [ 1:0] load_size_latch;
    always @(posedge clk) begin
        if (state == S_IDLE && load_ready_to_go) begin
            load_addr_latch <= cpu_addr;
            load_size_latch <= cpu_size;
        end
    end

    // 跟踪 AXI 桥是否已经接收了当次地址
    reg mem_addr_rcv;
    always @(posedge clk) begin
        if (~resetn)
            mem_addr_rcv <= 1'b0;
        else if (mem_req && mem_addr_ok && !mem_data_ok)
            mem_addr_rcv <= 1'b1;
        else if (mem_data_ok)
            mem_addr_rcv <= 1'b0;
    end

    // ------------------------------------
    // 向 Memory 桥发送请求信号
    // ------------------------------------
    wire req_load_active  = (state == S_IDLE && load_ready_to_go) || (state == S_DO_LOAD);
    wire req_store_active = (state == S_IDLE && !load_ready_to_go && store_ready_to_go) || (state == S_DO_STORE);

    assign mem_req   = (req_load_active || req_store_active) && !mem_addr_rcv;
    assign mem_wr    = req_store_active;
    assign mem_addr  = req_load_active ? (state == S_IDLE ? cpu_addr : load_addr_latch) : buf_addr[head];
    assign mem_size  = req_load_active ? (state == S_IDLE ? cpu_size : load_size_latch) : buf_size[head];
    assign mem_wstrb = req_load_active ? 4'd0 : buf_wstrb[head];
    assign mem_wdata = req_load_active ? 32'd0 : buf_wdata[head];

    // ------------------------------------
    // 返回给 CPU 的反馈信号
    // ------------------------------------
    wire store_accept = store_req && !buf_full;

    // 对于写请求：直接确认（0等待）。对于读请求，需要总线确认。
    assign cpu_addr_ok = (store_req && store_accept) ||
                         (load_req && req_load_active && mem_addr_ok && !mem_addr_rcv);

    assign cpu_data_ok = (store_req && store_accept) ||
                         (req_load_active && mem_data_ok);

    assign cpu_rdata   = mem_rdata;

    // ------------------------------------
    // 队列状态更新逻辑 (出入队)
    // ------------------------------------
    wire store_push = store_accept;
    wire store_pop  = req_store_active && mem_data_ok;

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            head  <= 2'd0;
            tail  <= 2'd0;
            count <= 3'd0;
            for (i=0; i<DEPTH; i=i+1) buf_valid[i] <= 1'b0;
        end else begin
            if (store_push) begin
                buf_valid[tail] <= 1'b1;
                buf_addr[tail]  <= cpu_addr;
                buf_wdata[tail] <= cpu_wdata;
                buf_wstrb[tail] <= cpu_wstrb;
                buf_size[tail]  <= cpu_size;
                tail <= tail + 2'd1;
            end

            if (store_pop) begin
                buf_valid[head] <= 1'b0;
                head <= head + 2'd1;
            end

            // 同步计数器维护
            case ({store_push, store_pop})
                2'b10: count <= count + 3'd1;
                2'b01: count <= count - 3'd1;
                default: count <= count;
            endcase
        end
    end

endmodule