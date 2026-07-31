
module la_pipe_cdc #(
    parameter HOLD_WATCHDOG = 32'd400000
)(
    input  wire        clk_cpu,
    input  wire        resetn_cpu,
    input  wire        clk_sram,
    input  wire        resetn_sram,
    input  wire        rload_go,
    input  wire [1:0]  rload_idx,
    input  wire        soft_idle,
    output reg         pipe_go,
    output reg  [1:0]  pipe_idx,
    input  wire        pipe_busy_s,
    input  wire        pipe_done_s,
    input  wire [31:0] pipe_retarget_pc_s,
    input  wire        pipe_giveup_s,
    output reg         pipe_hold,
    output reg         pipe_retarget_en,
    output reg  [31:0] pipe_retarget_pc,
    output reg         pipe_busy_c,
    output reg         soft_fallback_set
);
    reg done_tog_s;
    always @(posedge clk_sram) begin
        if (~resetn_sram) done_tog_s <= 1'b0;
        else if (pipe_done_s) done_tog_s <= ~done_tog_s;
    end

    reg gu_tog_s;
    always @(posedge clk_sram) begin
        if (~resetn_sram) gu_tog_s <= 1'b0;
        else if (pipe_giveup_s) gu_tog_s <= ~gu_tog_s;
    end

    reg [1:0] idx_lat_c;
    reg       go_tog_c;
    reg       wait_idle;
    reg       hold_arm;
    reg [31:0] hold_cnt;
    reg [1:0] busy_c, done_c, gu_c;
    reg       done_c_d, gu_c_d;
    reg [31:0] pc0, pc1;

    wire done_pulse = done_c[1] ^ done_c_d;
    wire gu_pulse   = gu_c[1] ^ gu_c_d;
    wire wd_fire    = wait_idle && (hold_cnt >= HOLD_WATCHDOG);

    always @(posedge clk_cpu) begin
        if (~resetn_cpu) begin
            go_tog_c          <= 1'b0;
            idx_lat_c         <= 2'd0;
            wait_idle         <= 1'b0;
            hold_arm          <= 1'b0;
            hold_cnt          <= 32'd0;
            busy_c            <= 2'b0;
            done_c            <= 2'b0;
            done_c_d          <= 1'b0;
            gu_c              <= 2'b0;
            gu_c_d            <= 1'b0;
            pipe_busy_c       <= 1'b0;
            pipe_hold         <= 1'b0;
            pipe_retarget_en  <= 1'b0;
            pipe_retarget_pc  <= 32'd0;
            soft_fallback_set <= 1'b0;
            pc0 <= 32'd0;
            pc1 <= 32'd0;
        end else begin
            busy_c   <= {busy_c[0], pipe_busy_s};
            done_c   <= {done_c[0], done_tog_s};
            done_c_d <= done_c[1];
            gu_c     <= {gu_c[0], gu_tog_s};
            gu_c_d   <= gu_c[1];
            pc0      <= pipe_retarget_pc_s;
            pc1      <= pc0;
            pipe_busy_c <= busy_c[1];
            pipe_retarget_en  <= 1'b0;
            soft_fallback_set <= 1'b0;

            if (rload_go) begin
                idx_lat_c <= rload_idx;
                wait_idle <= 1'b1;
                hold_arm  <= 1'b1;
                hold_cnt  <= 32'd0;
            end else if (done_pulse) begin
                wait_idle        <= 1'b0;
                hold_arm         <= 1'b0;
                hold_cnt         <= 32'd0;
                pipe_retarget_en <= 1'b1;
                pipe_retarget_pc <= pc1;
            end else if (gu_pulse || wd_fire) begin
                wait_idle         <= 1'b0;
                hold_arm          <= 1'b0;
                hold_cnt          <= 32'd0;
                soft_fallback_set <= 1'b1;
            end else begin
                if (wait_idle && soft_idle) begin
                    wait_idle <= 1'b0;
                    go_tog_c  <= ~go_tog_c;
                    hold_cnt  <= 32'd0;
                end else if (wait_idle) begin
                    hold_cnt <= hold_cnt + 32'd1;
                end
            end
            pipe_hold <= hold_arm || busy_c[1];
        end
    end

    reg [1:0] go_s;
    reg       go_s_d;
    reg [1:0] idx_s0, idx_s1;
    always @(posedge clk_sram) begin
        if (~resetn_sram) begin
            go_s     <= 2'b0;
            go_s_d   <= 1'b0;
            pipe_go  <= 1'b0;
            pipe_idx <= 2'd0;
            idx_s0   <= 2'd0;
            idx_s1   <= 2'd0;
        end else begin
            go_s   <= {go_s[0], go_tog_c};
            go_s_d <= go_s[1];
            idx_s0 <= idx_lat_c;
            idx_s1 <= idx_s0;
            pipe_go <= go_s[1] ^ go_s_d;
            if (go_s[1] ^ go_s_d)
                pipe_idx <= idx_s1;
        end
    end
endmodule
