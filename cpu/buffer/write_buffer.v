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
                    if (is_mmio_addr(cpu_addr) || is_mmio_addr(buf_addr[conflict_i]) ||
                        same_word_addr(cpu_addr, buf_addr[conflict_i]))
                        has_conflict = 1'b1;
                end
            end
        end
    end

    localparam S_IDLE     = 2'd0;
    localparam S_DO_LOAD  = 2'd1;
    localparam S_DO_STORE = 2'd2;

    reg [1:0] state;

    wire load_ready_to_go  = load_req && !has_conflict;
    wire store_completing  = (state == S_DO_STORE) && mem_data_ok;
    wire store_ready_to_go = (count > 3'd1) ||
                             ((count == 3'd1) && !store_completing);

    wire op_done   = ((state == S_DO_LOAD) || (state == S_DO_STORE)) && mem_data_ok;
    wire can_pick  = (state == S_IDLE) || op_done;
    wire pick_load  = can_pick && load_ready_to_go;
    wire pick_store = can_pick && !load_ready_to_go && store_ready_to_go;

    always @(posedge clk) begin
        if (~resetn) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    if (pick_load)       state <= S_DO_LOAD;
                    else if (pick_store) state <= S_DO_STORE;
                end
                S_DO_LOAD, S_DO_STORE: begin
                    if (mem_data_ok) begin
                        if (pick_load)       state <= S_DO_LOAD;
                        else if (pick_store) state <= S_DO_STORE;
                        else                 state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    reg [31:0] load_addr_latch;
    reg [ 1:0] load_size_latch;
    always @(posedge clk) begin
        if (pick_load) begin
            load_addr_latch <= cpu_addr;
            load_size_latch <= cpu_size;
        end
    end

    // Registered peeks of buf[head] / buf[head+1].  Store issue uses these so
    // mem_wdata is not a combo path through the load-CAM / buffer RAM (timing),
    // while still allowing same-cycle issue on pick_store.
    reg [31:0] q0_addr, q0_wdata;
    reg [ 3:0] q0_wstrb;
    reg [ 1:0] q0_size;
    reg [31:0] q1_addr, q1_wdata;
    reg [ 3:0] q1_wstrb;
    reg [ 1:0] q1_size;

    wire store_accept = store_req && !buf_full;
    wire store_push = store_accept;
    wire store_pop  = store_completing;

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            head  <= 2'd0;
            tail  <= 2'd0;
            count <= 3'd0;
            for (i = 0; i < DEPTH; i = i + 1) buf_valid[i] <= 1'b0;
            q0_addr <= 32'd0; q0_wdata <= 32'd0; q0_wstrb <= 4'd0; q0_size <= 2'd0;
            q1_addr <= 32'd0; q1_wdata <= 32'd0; q1_wstrb <= 4'd0; q1_size <= 2'd0;
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

            // q0 tracks head entry
            if (store_push && (count == 3'd0)) begin
                q0_addr  <= cpu_addr;
                q0_wdata <= cpu_wdata;
                q0_wstrb <= cpu_wstrb;
                q0_size  <= cpu_size;
            end else if (store_pop) begin
                if ((count == 3'd1) && store_push) begin
                    q0_addr  <= cpu_addr;
                    q0_wdata <= cpu_wdata;
                    q0_wstrb <= cpu_wstrb;
                    q0_size  <= cpu_size;
                end else if (count >= 3'd2) begin
                    q0_addr  <= q1_addr;
                    q0_wdata <= q1_wdata;
                    q0_wstrb <= q1_wstrb;
                    q0_size  <= q1_size;
                end
            end

            // q1 tracks head+1 entry
            if (store_push && (count == 3'd1) && !store_pop) begin
                q1_addr  <= cpu_addr;
                q1_wdata <= cpu_wdata;
                q1_wstrb <= cpu_wstrb;
                q1_size  <= cpu_size;
            end else if (store_pop && (count >= 3'd2)) begin
                if (store_push && (count == 3'd2)) begin
                    q1_addr  <= cpu_addr;
                    q1_wdata <= cpu_wdata;
                    q1_wstrb <= cpu_wstrb;
                    q1_size  <= cpu_size;
                end else if (count >= 3'd3) begin
                    q1_addr  <= buf_addr[head + 2'd2];
                    q1_wdata <= buf_wdata[head + 2'd2];
                    q1_wstrb <= buf_wstrb[head + 2'd2];
                    q1_size  <= buf_size[head + 2'd2];
                end
            end
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

    wire doing_load  = (state == S_DO_LOAD && !op_done) || pick_load;
    wire doing_store = (state == S_DO_STORE && !op_done) || pick_store;
    // On store complete → next store, q0 still holds the retiring entry this
    // cycle; issue from the already-registered q1 peek.
    wire        store_use_q1   = pick_store && store_completing;
    wire [31:0] store_iss_addr = store_use_q1 ? q1_addr  : q0_addr;
    wire [31:0] store_iss_data = store_use_q1 ? q1_wdata : q0_wdata;
    wire [ 3:0] store_iss_strb = store_use_q1 ? q1_wstrb : q0_wstrb;
    wire [ 1:0] store_iss_size = store_use_q1 ? q1_size  : q0_size;

    wire mem_slot_free = !mem_addr_rcv || mem_data_ok;

    assign mem_req   = (doing_load || doing_store) && mem_slot_free;
    assign mem_wr    = doing_store;
    assign mem_addr  = doing_store ? store_iss_addr :
                       (pick_load ? cpu_addr : load_addr_latch);
    assign mem_size  = doing_store ? store_iss_size :
                       (pick_load ? cpu_size : load_size_latch);
    assign mem_wstrb = doing_store ? store_iss_strb : 4'd0;
    assign mem_wdata = doing_store ? store_iss_data : 32'd0;

    assign cpu_addr_ok = (store_req && store_accept) ||
                         (load_req && doing_load && mem_slot_free && mem_addr_ok);

    assign cpu_data_ok = (store_req && store_accept) ||
                         ((state == S_DO_LOAD) && mem_data_ok);

    assign cpu_rdata   = mem_rdata;

endmodule
