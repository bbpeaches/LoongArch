module write_buffer #(
    parameter DEPTH = 4
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        cpu_req,
    input  wire        cpu_wr,
    input  wire [ 1:0] cpu_size,
    input  wire [31:0] cpu_addr,
    input  wire [ 3:0] cpu_wstrb,
    input  wire [31:0] cpu_wdata,
    output wire        cpu_addr_ok,
    output wire        cpu_data_ok,
    output wire [31:0] cpu_rdata,

    output wire        mem_req,
    output wire        mem_wr,
    output wire [ 1:0] mem_size,
    output wire [31:0] mem_addr,
    output wire [ 3:0] mem_wstrb,
    output wire [31:0] mem_wdata,
    input  wire        mem_addr_ok,
    input  wire        mem_data_ok,
    input  wire [31:0] mem_rdata,

    output wire        wb_empty
);
    // Board-proven soft path: any pending store blocks all loads.
    // (CAM conflict was an optimization; WaitBoot regressions force restore.)

    reg [31:0] buf_addr  [0:DEPTH-1];
    reg [31:0] buf_wdata [0:DEPTH-1];
    reg [ 3:0] buf_wstrb [0:DEPTH-1];
    reg [ 1:0] buf_size  [0:DEPTH-1];
    reg        buf_valid [0:DEPTH-1];

    reg [1:0] head;
    reg [1:0] tail;
    reg [2:0] count;

    wire buf_full  = (count == DEPTH);
    wire buf_empty = (count == 3'd0);
    assign wb_empty = buf_empty;

    wire has_conflict = !buf_empty;

    wire load_req  = cpu_req && !cpu_wr;
    wire store_req = cpu_req && cpu_wr;

    wire load_ready_to_go  = load_req && !has_conflict;
    wire store_ready_to_go = !buf_empty;

    localparam S_IDLE     = 2'd0;
    localparam S_DO_LOAD  = 2'd1;
    localparam S_DO_STORE = 2'd2;

    reg [1:0] state;

    always @(posedge clk) begin
        if (~resetn) begin
            state <= S_IDLE;
        end else case (state)
            S_IDLE: begin
                if (load_ready_to_go) begin
                    if (mem_req && mem_addr_ok && mem_data_ok)
                        state <= S_IDLE;
                    else
                        state <= S_DO_LOAD;
                end else if (store_ready_to_go) begin
                    if (mem_req && mem_addr_ok && mem_data_ok)
                        state <= S_IDLE;
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

    reg [31:0] load_addr_latch;
    reg [ 1:0] load_size_latch;
    always @(posedge clk) begin
        if (state == S_IDLE && load_ready_to_go && !(mem_req && mem_addr_ok)) begin
            load_addr_latch <= cpu_addr;
            load_size_latch <= cpu_size;
        end
    end

    reg mem_addr_rcv;
    always @(posedge clk) begin
        if (~resetn)
            mem_addr_rcv <= 1'b0;
        else if (mem_req && mem_addr_ok && !mem_data_ok)
            mem_addr_rcv <= 1'b1;
        else if (mem_data_ok)
            mem_addr_rcv <= 1'b0;
    end

    wire req_load_active  = (state == S_IDLE && load_ready_to_go) || (state == S_DO_LOAD);
    wire req_store_active = (state == S_IDLE && !load_ready_to_go && store_ready_to_go) || (state == S_DO_STORE);

    assign mem_req   = (req_load_active || req_store_active) && !mem_addr_rcv;
    assign mem_wr    = req_store_active;
    assign mem_addr  = req_load_active ? ((state == S_IDLE) ? cpu_addr : load_addr_latch) : buf_addr[head];
    assign mem_size  = req_load_active ? ((state == S_IDLE) ? cpu_size : load_size_latch) : buf_size[head];
    assign mem_wstrb = req_load_active ? 4'd0 : buf_wstrb[head];
    assign mem_wdata = req_load_active ? 32'd0 : buf_wdata[head];

    wire store_accept = store_req && !buf_full;

    assign cpu_addr_ok = (store_req && store_accept) ||
                         (load_req && req_load_active && mem_addr_ok && !mem_addr_rcv);

    assign cpu_data_ok = (store_req && store_accept) ||
                         (req_load_active && mem_data_ok);

    assign cpu_rdata   = mem_rdata;

    wire store_push = store_accept;
    wire store_pop  = req_store_active && (mem_req && mem_addr_ok && mem_data_ok || state == S_DO_STORE && mem_data_ok);

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            head  <= 2'd0;
            tail  <= 2'd0;
            count <= 3'd0;
            for (i = 0; i < DEPTH; i = i + 1) buf_valid[i] <= 1'b0;
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

            case ({store_push, store_pop})
                2'b10: count <= count + 3'd1;
                2'b01: count <= count - 3'd1;
                default: count <= count;
            endcase
        end
    end

endmodule
