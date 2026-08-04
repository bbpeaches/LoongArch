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

    output wire        mem_read_req,
    output wire [ 1:0] mem_read_size,
    output wire [31:0] mem_read_addr,
    input  wire        mem_read_addr_ok,
    input  wire        mem_read_data_ok,
    input  wire [31:0] mem_read_rdata,

    output wire        mem_write_req,
    output wire [ 1:0] mem_write_size,
    output wire [31:0] mem_write_addr,
    output wire [ 3:0] mem_write_wstrb,
    output wire [31:0] mem_write_wdata,
    input  wire        mem_write_addr_ok,
    input  wire        mem_write_data_ok,

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

    wire load_ready_to_go  = load_req && !has_conflict;
    reg load_busy, load_addr_sent;
    reg [31:0] load_addr_latch;
    reg [ 1:0] load_size_latch;
    always @(posedge clk) begin
        if (~resetn) begin
            load_busy      <= 1'b0;
            load_addr_sent <= 1'b0;
            load_addr_latch <= 32'd0;
            load_size_latch <= 2'd0;
        end else begin
            if (mem_read_data_ok) begin
                load_busy      <= 1'b0;
                load_addr_sent <= 1'b0;
            end else if (!load_busy && load_ready_to_go) begin
                load_busy       <= 1'b1;
                load_addr_sent  <= mem_read_addr_ok;
                load_addr_latch <= cpu_addr;
                load_size_latch <= cpu_size;
            end else if (load_busy && !load_addr_sent && mem_read_addr_ok) begin
                load_addr_sent <= 1'b1;
            end
        end
    end

    reg [31:0] q0_addr, q0_wdata;
    reg [ 3:0] q0_wstrb;
    reg [ 1:0] q0_size;
    reg [31:0] q1_addr, q1_wdata;
    reg [ 3:0] q1_wstrb;
    reg [ 1:0] q1_size;

    wire store_accept = store_req && !buf_full;
    wire store_push = store_accept;
    reg store_busy;
    wire store_pop = store_busy && mem_write_data_ok;

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

    always @(posedge clk) begin
        if (~resetn)
            store_busy <= 1'b0;
        else if (store_pop)
            store_busy <= 1'b0;
        else if (!store_busy && !buf_empty && mem_write_addr_ok)
            store_busy <= 1'b1;
    end

    wire start_load = !load_busy && load_ready_to_go;
    assign mem_read_req  = start_load || (load_busy && !load_addr_sent);
    assign mem_read_addr = start_load ? cpu_addr : load_addr_latch;
    assign mem_read_size = start_load ? cpu_size : load_size_latch;

    assign mem_write_req   = !store_busy && !buf_empty;
    assign mem_write_addr  = q0_addr;
    assign mem_write_size  = q0_size;
    assign mem_write_wstrb = q0_wstrb;
    assign mem_write_wdata = q0_wdata;

    assign cpu_addr_ok = (store_req && store_accept) ||
                         (load_req && mem_read_req && mem_read_addr_ok);

    assign cpu_data_ok = (store_req && store_accept) ||
                         (load_busy && mem_read_data_ok);

    assign cpu_rdata   = mem_read_rdata;

endmodule
