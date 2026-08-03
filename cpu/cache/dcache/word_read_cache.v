module word_read_cache #(
    parameter INDEX_WIDTH = 16,
    parameter BANK_SELECT_WIDTH = 2
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
    input  wire        mem_empty,
    output wire        cache_empty
);
    localparam LINE_COUNT = (1 << INDEX_WIDTH);
    localparam TAG_WIDTH  = 21 - INDEX_WIDTH;
    localparam BANK_COUNT = (1 << BANK_SELECT_WIDTH);
    localparam BANK_ADDR_WIDTH = INDEX_WIDTH - BANK_SELECT_WIDTH;
    localparam BANK_DEPTH = (1 << BANK_ADDR_WIDTH);
    localparam S_IDLE   = 2'd0;
    localparam S_LOOKUP = 2'd1;
    localparam S_MISS   = 2'd2;

    reg [1:0] state;
    reg [31:0] req_addr;
    reg [1:0]  req_size;

    // The physical BaseRAM and ExtRAM AXI windows are 0x1c00_0000 through
    // 0x1c7f_ffff. MMIO is deliberately excluded.
    wire cpu_cacheable = (cpu_addr[31:23] == 9'h038);
    wire [INDEX_WIDTH-1:0] cpu_index = cpu_addr[INDEX_WIDTH+1:2];
    wire [TAG_WIDTH-1:0] cpu_tag = cpu_addr[22:INDEX_WIDTH+2];
    wire [INDEX_WIDTH-1:0] req_index = req_addr[INDEX_WIDTH+1:2];
    wire [TAG_WIDTH-1:0] req_tag = req_addr[22:INDEX_WIDTH+2];
    wire req_cacheable = (req_addr[31:23] == 9'h038);

    reg scan_active;
    reg cache_enabled;
    reg [INDEX_WIDTH-1:0] scan_index;

    always @(posedge clk) begin
        if (!resetn) begin
            scan_active   <= 1'b1;
            cache_enabled <= 1'b0;
            scan_index    <= {INDEX_WIDTH{1'b0}};
        end else if (scan_active) begin
            if (&scan_index) begin
                scan_active <= 1'b0;
            end else begin
                scan_index <= scan_index + {{(INDEX_WIDTH-1){1'b0}}, 1'b1};
            end
        end else if (!cache_enabled && state == S_IDLE && !cpu_req) begin
            cache_enabled <= 1'b1;
        end
    end

    wire disabled_passthrough = !cache_enabled;
    wire store_passthrough = cache_enabled && state == S_IDLE && cpu_req && cpu_wr;
    wire miss_passthrough = cache_enabled && state == S_MISS;

    assign mem_req   = disabled_passthrough ? cpu_req   :
                       store_passthrough    ? cpu_req   :
                       miss_passthrough     ? 1'b1      : 1'b0;
    assign mem_wr    = disabled_passthrough ? cpu_wr    :
                       store_passthrough    ? 1'b1      : 1'b0;
    assign mem_size  = disabled_passthrough ? cpu_size  :
                       store_passthrough    ? cpu_size  : req_size;
    assign mem_addr  = disabled_passthrough ? cpu_addr  :
                       store_passthrough    ? cpu_addr  : req_addr;
    assign mem_wstrb = disabled_passthrough ? cpu_wstrb :
                       store_passthrough    ? cpu_wstrb : 4'd0;
    assign mem_wdata = disabled_passthrough ? cpu_wdata :
                       store_passthrough    ? cpu_wdata : 32'd0;

    wire lookup_start = cache_enabled && state == S_IDLE && cpu_req &&
                        !cpu_wr && cpu_cacheable;
    wire store_lookup_start = store_passthrough && mem_data_ok && cpu_cacheable;
    wire ram_read_en = lookup_start || store_lookup_start;
    wire [INDEX_WIDTH-1:0] ram_read_index = cpu_index;
    wire [BANK_SELECT_WIDTH-1:0] ram_read_bank =
        ram_read_index[INDEX_WIDTH-1:BANK_ADDR_WIDTH];
    wire [BANK_ADDR_WIDTH-1:0] ram_read_offset =
        ram_read_index[BANK_ADDR_WIDTH-1:0];
    reg [BANK_SELECT_WIDTH-1:0] ram_read_bank_q;
    wire [31:0] ram_read_data;
    wire [TAG_WIDTH:0] ram_read_meta;

    always @(posedge clk) begin
        if (ram_read_en) ram_read_bank_q <= ram_read_bank;
    end

    reg store_pipe_valid;
    reg [31:0] store_pipe_addr;
    reg [31:0] store_pipe_data;
    reg [3:0]  store_pipe_strb;
    wire [TAG_WIDTH-1:0] store_pipe_tag = store_pipe_addr[22:INDEX_WIDTH+2];
    wire [INDEX_WIDTH-1:0] store_pipe_index = store_pipe_addr[INDEX_WIDTH+1:2];
    wire store_pipe_hit = store_pipe_valid && ram_read_meta[TAG_WIDTH] &&
                          (ram_read_meta[TAG_WIDTH-1:0] == store_pipe_tag);

    reg lookup_forward_valid;
    reg [31:0] lookup_forward_data;
    reg [3:0]  lookup_forward_strb;

    function [31:0] merge_bytes;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] strb;
        begin
            merge_bytes = old_word;
            if (strb[0]) merge_bytes[ 7: 0] = new_word[ 7: 0];
            if (strb[1]) merge_bytes[15: 8] = new_word[15: 8];
            if (strb[2]) merge_bytes[23:16] = new_word[23:16];
            if (strb[3]) merge_bytes[31:24] = new_word[31:24];
        end
    endfunction

    wire [31:0] lookup_data = lookup_forward_valid ?
                              merge_bytes(ram_read_data, lookup_forward_data,
                                          lookup_forward_strb) : ram_read_data;
    wire lookup_hit = ram_read_meta[TAG_WIDTH] &&
                      (ram_read_meta[TAG_WIDTH-1:0] == req_tag);
    wire fill_fire = cache_enabled && state == S_MISS && req_cacheable && mem_data_ok;

    // Split the 64 K-entry arrays into four 16 K-entry simple dual-port
    // memories. This preserves BRAM inference in Vivado 2019.2.
    wire data_write_fire = fill_fire || store_pipe_hit;
    wire [INDEX_WIDTH-1:0] data_write_index =
        fill_fire ? req_index : store_pipe_index;
    wire [31:0] data_write_value =
        fill_fire ? mem_rdata :
        merge_bytes(ram_read_data, store_pipe_data, store_pipe_strb);
    wire [BANK_SELECT_WIDTH-1:0] data_write_bank =
        data_write_index[INDEX_WIDTH-1:BANK_ADDR_WIDTH];
    wire [BANK_ADDR_WIDTH-1:0] data_write_offset =
        data_write_index[BANK_ADDR_WIDTH-1:0];

    // Metadata is invalidated sequentially so valid bits map to BRAM rather
    // than resettable flip-flops. Requests bypass the cache during the scan.
    wire meta_write_fire = scan_active || fill_fire;
    wire [INDEX_WIDTH-1:0] meta_write_index =
        scan_active ? scan_index : req_index;
    wire [TAG_WIDTH:0] meta_write_value =
        scan_active ? {(TAG_WIDTH+1){1'b0}} : {1'b1, req_tag};
    wire [BANK_SELECT_WIDTH-1:0] meta_write_bank =
        meta_write_index[INDEX_WIDTH-1:BANK_ADDR_WIDTH];
    wire [BANK_ADDR_WIDTH-1:0] meta_write_offset =
        meta_write_index[BANK_ADDR_WIDTH-1:0];

    wire [31:0] data_bank_rdata [0:BANK_COUNT-1];
    wire [TAG_WIDTH:0] meta_bank_rdata [0:BANK_COUNT-1];
    genvar cache_bank_i;
    generate
        for (cache_bank_i = 0; cache_bank_i < BANK_COUNT;
             cache_bank_i = cache_bank_i + 1) begin : gen_word_cache_bank
            localparam [BANK_SELECT_WIDTH-1:0] BANK_ID = cache_bank_i;

            simple_dual_port_ram #(
                .WIDTH(32), .DEPTH(BANK_DEPTH),
                .ADDR_WIDTH(BANK_ADDR_WIDTH), .RAM_STYLE("block")
            ) data_bank (
                .clk(clk),
                .r_en(ram_read_en && ram_read_bank == BANK_ID),
                .r_addr(ram_read_offset), .r_data(data_bank_rdata[cache_bank_i]),
                .w_en(data_write_fire && data_write_bank == BANK_ID),
                .w_addr(data_write_offset), .w_data(data_write_value)
            );

            simple_dual_port_ram #(
                .WIDTH(TAG_WIDTH+1), .DEPTH(BANK_DEPTH),
                .ADDR_WIDTH(BANK_ADDR_WIDTH), .RAM_STYLE("block")
            ) meta_bank (
                .clk(clk),
                .r_en(ram_read_en && ram_read_bank == BANK_ID),
                .r_addr(ram_read_offset), .r_data(meta_bank_rdata[cache_bank_i]),
                .w_en(meta_write_fire && meta_write_bank == BANK_ID),
                .w_addr(meta_write_offset), .w_data(meta_write_value)
            );
        end
    endgenerate

    assign ram_read_data = data_bank_rdata[ram_read_bank_q];
    assign ram_read_meta = meta_bank_rdata[ram_read_bank_q];

    always @(posedge clk) begin
        if (!resetn) begin
            store_pipe_valid <= 1'b0;
            lookup_forward_valid <= 1'b0;
        end else begin
            store_pipe_valid <= store_lookup_start;
            if (store_lookup_start) begin
                store_pipe_addr <= cpu_addr;
                store_pipe_data <= cpu_wdata;
                store_pipe_strb <= cpu_wstrb;
            end
            if (lookup_start) begin
                lookup_forward_valid <= store_pipe_hit &&
                                        (store_pipe_addr[31:2] == cpu_addr[31:2]);
                lookup_forward_data <= store_pipe_data;
                lookup_forward_strb <= store_pipe_strb;
            end else begin
                lookup_forward_valid <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn || !cache_enabled) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    if (cpu_req && !cpu_wr) begin
                        req_addr <= cpu_addr;
                        req_size <= cpu_size;
                        state <= cpu_cacheable ? S_LOOKUP : S_MISS;
                    end
                end
                S_LOOKUP: state <= lookup_hit ? S_IDLE : S_MISS;
                S_MISS: begin
                    if (mem_data_ok) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign cpu_addr_ok = disabled_passthrough ? mem_addr_ok :
                         store_passthrough    ? mem_addr_ok :
                         (state == S_LOOKUP && lookup_hit) ? 1'b1 :
                         (state == S_MISS) ? mem_addr_ok : 1'b0;
    assign cpu_data_ok = disabled_passthrough ? mem_data_ok :
                         store_passthrough    ? mem_data_ok :
                         (state == S_LOOKUP && lookup_hit) ? 1'b1 :
                         (state == S_MISS) ? mem_data_ok : 1'b0;
    assign cpu_rdata = (state == S_LOOKUP && lookup_hit) ? lookup_data : mem_rdata;
    assign cache_empty = mem_empty && (state == S_IDLE) && !store_pipe_valid;
endmodule