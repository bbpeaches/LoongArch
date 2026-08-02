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

    wire load_req  = cpu_req && !cpu_wr;
    wire store_req = cpu_req && cpu_wr;

    function is_mmio_addr;
        input [31:0] addr;
        begin
            is_mmio_addr = (addr[31:20] == 12'h1f0);
        end
    endfunction

    function same_word_addr;
        input [31:0] addr_a;
        input [31:0] addr_b;
        reg [5:0] word_addr_match;
        begin
            // This is a conservative load-after-store conflict filter.  A
            // true word match always matches every slice below, so no stale
            // read can pass a buffered write.  Non-identical words may very
            // rarely share this 18-bit fingerprint; that only postpones an
            // otherwise independent load until the older store completes.
            // Six 3-bit comparisons and one LUT6 reduction save one logic
            // level versus the exact 30-bit CAM comparison on the EX-address
            // path, while retaining enough address-region bits to avoid
            // systematic BaseRAM/ExtRAM streaming aliases.
            word_addr_match[0] = (addr_a[ 4: 2] == addr_b[ 4: 2]);
            word_addr_match[1] = (addr_a[ 7: 5] == addr_b[ 7: 5]);
            word_addr_match[2] = (addr_a[10: 8] == addr_b[10: 8]);
            word_addr_match[3] = (addr_a[17:15] == addr_b[17:15]);
            word_addr_match[4] = (addr_a[20:18] == addr_b[20:18]);
            word_addr_match[5] = (addr_a[23:21] == addr_b[23:21]);
            same_word_addr = &word_addr_match;
        end
    endfunction

    reg has_conflict;
    integer conflict_i;
    always @(*) begin
        has_conflict = 1'b0;
        if (load_req) begin
            for (conflict_i = 0; conflict_i < DEPTH; conflict_i = conflict_i + 1) begin
                if (buf_valid[conflict_i]) begin
                    if (is_mmio_addr(cpu_addr) || is_mmio_addr(buf_addr[conflict_i]) || same_word_addr(cpu_addr, buf_addr[conflict_i]))
                        has_conflict = 1'b1;
                end
            end
        end
    end

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
                    // The integrated SRAM slave has at least one response
                    // wait cycle, so a newly issued request cannot complete
                    // in this S_IDLE cycle.
                    state <= S_DO_LOAD;
                end else if (store_ready_to_go) begin
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
        // These values are only consumed after S_DO_LOAD is entered.  Capture
        // every idle-cycle load request so the address-CAM and AXI-ready
        // decision do not sit on the latch enable path.
        if (state == S_IDLE && load_req) begin
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

    // A queued store normally starts directly from idle.  When an incoming
    // load aliases a buffered store, however, it used to make the load CAM,
    // the store-launch muxes, and the AXI write capture all one combinational
    // path.  First enter S_DO_STORE for that collision case instead.  It does
    // not alter ordering or any non-conflicting request: a CPU store (or an
    // idle cycle) still launches the queued store immediately, while an
    // aliased load was already required to wait for that store to complete.
    wire idle_store_without_load = (state == S_IDLE) &&
                                  store_ready_to_go && !load_req;
    wire req_store_active = idle_store_without_load || (state == S_DO_STORE);

    assign mem_req   = (req_load_active || req_store_active) && !mem_addr_rcv;
    assign mem_wr    = req_store_active;
    assign mem_addr  = req_load_active ? ((state == S_IDLE) ? cpu_addr : load_addr_latch) : buf_addr[head];
    assign mem_size  = req_load_active ? ((state == S_IDLE) ? cpu_size : load_size_latch) : buf_size[head];
    assign mem_wstrb = req_load_active ? 4'd0 : buf_wstrb[head];
    assign mem_wdata = req_load_active ? 32'd0 : buf_wdata[head];

    wire store_accept = store_req && !buf_full;

    assign cpu_addr_ok = (store_req && store_accept) ||
                         (load_req && req_load_active && mem_addr_ok && !mem_addr_rcv);

    // Read data returns through the AXI bridge after the request has entered
    // S_DO_LOAD.  Do not let the current request/address CAM feed the data
    // response qualifier: it cannot complete a new AXI read in the same
    // cycle, and keeping that zero-latency branch creates a long false
    // EX-address-to-global-stall combinational cone.
    assign cpu_data_ok = (store_req && store_accept) ||
                         ((state == S_DO_LOAD) && mem_data_ok);

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
