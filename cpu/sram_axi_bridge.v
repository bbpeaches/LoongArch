module sram_axi_bridge(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] icache_araddr,
    input  wire        icache_arvalid,
    output wire        icache_arready,
    
    output wire [31:0] icache_rdata,
    output wire        icache_rlast,
    output wire        icache_rvalid,
    input  wire        icache_rready,

    input  wire        data_req,
    input  wire        data_wr,
    input  wire [ 1:0] data_size,
    input  wire [31:0] data_addr,
    input  wire [ 3:0] data_wstrb,
    input  wire [31:0] data_wdata,
    output wire        data_addr_ok,
    output wire        data_data_ok,
    output wire [31:0] data_rdata,

    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,
    
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,
    
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready
);

    wire data_r_data_ok = rvalid && rready && (rid == 4'd1);
    
    wire data_r_data_last = rvalid && rready && (rid == 4'd1) && rlast; 
    
    reg data_ar_acc;
    always @(posedge clk) begin
        if(!resetn) data_ar_acc <= 0;
        else if(data_addr_ok && data_req && !data_wr && !data_r_data_last) data_ar_acc <= 1;
        else if(data_r_data_last) data_ar_acc <= 0;
    end

    wire do_data_ar = data_req && !data_wr && !data_ar_acc;

    reg holding_ar;
    reg [3:0]  held_arid;
    reg [31:0] held_araddr;
    reg [2:0]  held_arsize;
    reg [7:0]  held_arlen;
    reg [1:0]  held_arburst;

    always @(posedge clk) begin
        if(!resetn) holding_ar <= 0;
        else if(arvalid && arready) holding_ar <= 0;
        else if(arvalid && !arready) begin
            holding_ar   <= 1;
            held_arid    <= arid;
            held_araddr  <= araddr;
            held_arsize  <= arsize;
            held_arlen   <= arlen;
            held_arburst <= arburst;
        end
    end

    wire do_data_burst = (data_size == 2'b11); 

    assign arvalid = holding_ar ? 1'b1 : (do_data_ar || icache_arvalid);
    assign arid    = holding_ar ? held_arid  : (do_data_ar ? 4'd1 : 4'd0);
    assign araddr  = holding_ar ? held_araddr : (do_data_ar ? data_addr : icache_araddr);
    
    assign arsize  = holding_ar ? held_arsize : (do_data_ar ? (do_data_burst ? 3'd2 : {1'b0, data_size}) : 3'd2);
    assign arlen   = holding_ar ? held_arlen  : (do_data_ar ? (do_data_burst ? 8'd3 : 8'd0) : 8'd7);
    
    assign arburst = holding_ar ? held_arburst : (do_data_ar ? 2'b01 : 2'b10);
    
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign icache_arready = arvalid && arready && (arid == 4'd0);

    wire data_req_w = data_req && data_wr;

    reg aw_sent, w_sent;
    always @(posedge clk) begin
        if(!resetn) aw_sent <= 0;
        else if(bvalid && bready) aw_sent <= 0;
        else if(awvalid && awready) aw_sent <= 1;
    end
    always @(posedge clk) begin
        if(!resetn) w_sent <= 0;
        else if(bvalid && bready) w_sent <= 0;
        else if(wvalid && wready) w_sent <= 1;
    end

    reg holding_aw;
    reg [31:0] held_awaddr;
    reg [2:0]  held_awsize;
    always @(posedge clk) begin
        if(!resetn) holding_aw <= 0;
        else if(awvalid && awready) holding_aw <= 0;
        else if(awvalid && !awready) begin
            holding_aw  <= 1;
            held_awaddr <= awaddr;
            held_awsize <= awsize;
        end
    end

    reg holding_w;
    reg [31:0] held_wdata;
    reg [3:0]  held_wstrb;
    always @(posedge clk) begin
        if(!resetn) holding_w <= 0;
        else if(wvalid && wready) holding_w <= 0;
        else if(wvalid && !wready) begin
            holding_w  <= 1;
            held_wdata <= wdata;
            held_wstrb <= wstrb;
        end
    end

    assign awvalid = holding_aw ? 1'b1 : (data_req_w && !aw_sent);
    assign awaddr  = holding_aw ? held_awaddr : data_addr;
    assign awsize  = holding_aw ? held_awsize : {1'b0, data_size};
    assign awid    = 4'd1;
    assign awlen   = 8'd0;
    assign awburst = 2'b01;
    assign awlock  = 2'd0;
    assign awcache = 4'd0;
    assign awprot  = 3'd0;

    assign wvalid  = holding_w ? 1'b1 : (data_req_w && !w_sent);
    assign wdata   = holding_w ? held_wdata : data_wdata;
    assign wstrb   = holding_w ? held_wstrb : data_wstrb;
    assign wid     = 4'd1;
    assign wlast   = 1'b1;

    wire write_addr_ok = (awvalid && awready && w_sent) ||
                         (wvalid && wready && aw_sent) ||
                         (awvalid && awready && wvalid && wready);

    assign data_addr_ok = (arvalid && arready && (arid == 4'd1)) || (data_req_w && write_addr_ok);

    assign rready = (rvalid && rid == 4'd0) ? icache_rready : 1'b1; 
    assign bready = 1'b1;

    assign icache_rdata  = rdata;
    assign icache_rlast  = rlast;
    assign icache_rvalid = rvalid && (rid == 4'd0);

    assign data_data_ok = (rvalid && (rid == 4'd1)) || (bvalid && (bid == 4'd1));
    assign data_rdata   = rdata;

endmodule