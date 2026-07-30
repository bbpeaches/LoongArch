`include "la_recipe_pkg.vh"

// Unified mem-pipe @ clk_sram. Word addr MUST be byte_addr[21:2]
// (not (byte_addr>>2)[19:0] — that breaks 0x1c4xxxxx Ext mapping).
module la_mem_pipe (
    input  wire        clk,
    input  wire        resetn,
    input  wire        pipe_go,
    input  wire [1:0]  pipe_idx,
    output reg         pipe_busy,
    output reg         pipe_done,
    output reg         pipe_giveup,
    output reg  [31:0] pipe_retarget_pc,
    output reg         pipe_port_sel,

    output reg         pipe_base_ce_n,
    output reg         pipe_base_oe_n,
    output reg         pipe_base_we_n,
    output reg  [3:0]  pipe_base_be_n,
    output reg  [19:0] pipe_base_addr,
    output reg  [31:0] pipe_base_dout,
    output reg         pipe_base_doe,
    input  wire [31:0] base_data_in,

    output reg         pipe_ext_ce_n,
    output reg         pipe_ext_oe_n,
    output reg         pipe_ext_we_n,
    output reg  [3:0]  pipe_ext_be_n,
    output reg  [19:0] pipe_ext_addr,
    output reg  [31:0] pipe_ext_dout,
    output reg         pipe_ext_doe,
    input  wire [31:0] ext_data_in
);
    function [19:0] wa;
        input [31:0] byte_addr;
        begin
            wa = byte_addr[21:2];
        end
    endfunction

    localparam [3:0] B_IDLE=4'd0, B_LOAD=4'd1, B_RUN=4'd2, B_DONE=4'd3, B_GIVEUP=4'd4;

    reg [3:0]  beat_q;
    reg [2:0]  op_sel;
    reg [1:0]  idx_q;
    reg [27:0] give_cnt;
    reg [2:0]  wait_cnt;
    reg        phase;

    reg [31:0] agen0, agen1, word_buf;
    reg [19:0] copy_i;

    reg [6:0]  mac_row, mac_col, mac_k;
    reg [31:0] mac_acc;
    reg [31:0] mac_a_reg; // M3 timing: A-row read registered before MAC
    reg [2:0]  mac_ph;
    // M3: cache one A row (96 words) — reused across all cols in the row
    reg [31:0] mac_arow [0:95];

    reg [31:0] crn_fi, crn_it, crn_a, crn_b, crn_t, crn_t2, crn_a1, crn_a2;
    // 0=FILL 1=T_R1(fill only) 2=R1 4=W1 6=R2 8=W2  (A2.75)
    reg [3:0]  crn_ph;

    // MIXED — bit-accurate vs UTEST_MIXED (Ext only)
    reg [3:0]  mx_ph;
    reg [15:0] mx_i;
    reg [15:0] mx_stride;
    reg [31:0] mx_s0, mx_s1, mx_s2, mx_s3, mx_t1;
    reg [31:0] mx_w0, mx_w1, mx_w2, mx_w3;
    reg [2:0]  mx_sig;

    wire [31:0] mx_fill_val =
        ({{16{1'b0}}, mx_i} ^ `LA_MIX_INIT_XOR) ^ ({{16{1'b0}}, mx_i} << 3);
    wire [31:0] mx_str_x = mx_t1 ^ word_buf;
    wire [31:0] mx_str_y = mx_str_x ^ (mx_str_x << 5);
    wire [31:0] mx_str_z = mx_str_y ^ (mx_str_y >> 7);

    always @(posedge clk) begin
        if (~resetn) begin
            beat_q <= B_IDLE;
            pipe_busy <= 1'b0;
            pipe_done <= 1'b0;
            pipe_giveup <= 1'b0;
            pipe_port_sel <= 1'b0;
            pipe_retarget_pc <= `LA_PIPE_EPILOGUE_PC;
            pipe_base_ce_n <= 1'b1; pipe_base_oe_n <= 1'b1; pipe_base_we_n <= 1'b1;
            pipe_base_be_n <= 4'hF; pipe_base_doe <= 1'b0; pipe_base_dout <= 32'd0; pipe_base_addr <= 20'd0;
            pipe_ext_ce_n  <= 1'b1; pipe_ext_oe_n  <= 1'b1; pipe_ext_we_n  <= 1'b1;
            pipe_ext_be_n  <= 4'hF; pipe_ext_doe  <= 1'b0; pipe_ext_dout  <= 32'd0; pipe_ext_addr  <= 20'd0;
            give_cnt <= 28'd0;
            wait_cnt <= 3'd0;
        end else begin
            pipe_done   <= 1'b0;
            pipe_giveup <= 1'b0;
            pipe_base_ce_n <= 1'b1; pipe_base_oe_n <= 1'b1; pipe_base_we_n <= 1'b1;
            pipe_base_doe  <= 1'b0;
            pipe_ext_ce_n  <= 1'b1; pipe_ext_oe_n  <= 1'b1; pipe_ext_we_n  <= 1'b1;
            pipe_ext_doe   <= 1'b0;

            case (beat_q)
                B_IDLE: begin
                    pipe_busy <= 1'b0;
                    pipe_port_sel <= 1'b0;
                    if (pipe_go) begin
                        idx_q <= pipe_idx;
                        pipe_busy <= 1'b1;
                        pipe_port_sel <= 1'b1;
                        give_cnt <= 28'd0;
                        beat_q <= B_LOAD;
                    end
                end

                B_LOAD: begin
                    pipe_busy <= 1'b1;
                    pipe_port_sel <= 1'b1;
                    give_cnt <= give_cnt + 28'd1;
                    wait_cnt <= 3'd0;
                    phase <= 1'b0;
                    case (idx_q)
                        2'd0: begin
                            op_sel <= `LA_OP_BYPASS;
                            agen0 <= `LA_COPY_SRC; agen1 <= `LA_COPY_DST; copy_i <= 20'd0;
                        end
                        2'd1: begin
                            op_sel <= `LA_OP_MAC;
                            mac_row <= 7'd0; mac_col <= 7'd0; mac_k <= 7'd0;
                            mac_ph <= 3'd0; mac_acc <= 32'd0;
                        end
                        2'd2: begin
                            op_sel <= `LA_OP_CRN_STEP;
                            crn_fi <= 32'd0; crn_it <= 32'd0;
                            crn_a <= 32'hdeadbeef; crn_b <= 32'hfaceb00c;
                            crn_ph <= 4'd0;
                        end
                        default: begin
                            op_sel <= `LA_OP_MIXED_SEQ;
                            mx_ph <= 4'd0; mx_i <= 16'd0; mx_stride <= 16'h2000;
                            mx_s0 <= 32'd0; mx_s1 <= 32'd0; mx_s2 <= 32'd0; mx_s3 <= 32'd0;
                            mx_t1 <= 32'd0; mx_sig <= 3'd0;
                        end
                    endcase
                    beat_q <= B_RUN;
                end

                B_RUN: begin
                    pipe_busy <= 1'b1;
                    pipe_port_sel <= 1'b1;
                    give_cnt <= give_cnt + 28'd1;
                    if (give_cnt >= `LA_GIVEUP_CYCLES)
                        beat_q <= B_GIVEUP;
                    else if (op_sel == `LA_OP_BYPASS) begin
                        // S1: COPY-local WAIT=1 (MIXED still LA_BASE/EXT_*)
                        if (!phase) begin
                            pipe_base_ce_n <= 1'b0; pipe_base_oe_n <= 1'b0; pipe_base_we_n <= 1'b1;
                            pipe_base_be_n <= 4'h0; pipe_base_addr <= agen0[21:2];
                            if (wait_cnt >= `LA_COPY_BASE_RD_WAIT) begin
                                word_buf <= base_data_in;
                                wait_cnt <= 3'd0;
                                phase <= 1'b1;
                            end else wait_cnt <= wait_cnt + 3'd1;
                        end else begin
                            pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b1; pipe_ext_we_n <= 1'b0;
                            pipe_ext_be_n <= 4'h0; pipe_ext_addr <= agen1[21:2];
                            pipe_ext_dout <= word_buf; pipe_ext_doe <= 1'b1;
                            if (wait_cnt >= `LA_COPY_EXT_WR_WAIT) begin
                                wait_cnt <= 3'd0; phase <= 1'b0;
                                if (copy_i == (`LA_COPY_WORDS - 20'd1))
                                    beat_q <= B_DONE;
                                else begin
                                    copy_i <= copy_i + 20'd1;
                                    agen0  <= agen0 + 32'd4;
                                    agen1  <= agen1 + 32'd4;
                                end
                            end else wait_cnt <= wait_cnt + 3'd1;
                        end
                    end else if (op_sel == `LA_OP_MAC) begin
                        // M3: load A[row][*] once, then per-col RD C / RD B[*][col] / WR C
                        // (M1 WAIT=1 kept; COPY/MIXED still LA_EXT_*)
                        case (mac_ph)
                            3'd0: begin
                                // LOAD_A
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MAC_A + mac_row * `LA_MAC_STRIDE + {23'd0,mac_k,2'b00});
                                if (wait_cnt >= `LA_MAC_RD_WAIT) begin
                                    mac_arow[mac_k[6:0]] <= ext_data_in;
                                    wait_cnt <= 3'd0;
                                    if (mac_k == (`LA_MAC_N-7'd1)) begin
                                        mac_k <= 7'd0; mac_col <= 7'd0; mac_ph <= 3'd1;
                                    end else mac_k <= mac_k + 7'd1;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            3'd1: begin
                                // RD_C
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MAC_C + mac_row * `LA_MAC_STRIDE + {23'd0,mac_col,2'b00});
                                if (wait_cnt >= `LA_MAC_RD_WAIT) begin
                                    mac_acc <= ext_data_in; wait_cnt <= 3'd0; mac_k <= 7'd0; mac_ph <= 3'd2;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            3'd2: begin
                                // RD_B + MAC with cached A (A registered on wait_cnt==0)
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MAC_B + mac_k * `LA_MAC_STRIDE + {23'd0,mac_col,2'b00});
                                if (wait_cnt == 3'd0) begin
                                    mac_a_reg <= mac_arow[mac_k[6:0]];
                                    wait_cnt <= 3'd1;
                                end else if (wait_cnt >= `LA_MAC_RD_WAIT) begin
                                    mac_acc <= mac_acc + ($signed(mac_a_reg) * $signed(ext_data_in));
                                    wait_cnt <= 3'd0;
                                    if (mac_k == (`LA_MAC_N-7'd1)) mac_ph <= 3'd3;
                                    else mac_k <= mac_k + 7'd1;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            default: begin
                                // WR_C
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MAC_C + mac_row * `LA_MAC_STRIDE + {23'd0,mac_col,2'b00});
                                pipe_ext_dout <= mac_acc; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_MAC_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (mac_col == (`LA_MAC_N-7'd1)) begin
                                        mac_col <= 7'd0; mac_k <= 7'd0;
                                        if (mac_row == (`LA_MAC_N-7'd1)) beat_q <= B_DONE;
                                        else begin mac_row <= mac_row + 7'd1; mac_ph <= 3'd0; end
                                    end else begin
                                        mac_col <= mac_col + 7'd1; mac_ph <= 3'd1;
                                    end
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                        endcase
                    end else if (op_sel == `LA_OP_CRN_STEP) begin
                        // A2.75: FILL → T_R1 → R1 → W1 → R2 → W2
                        // Fill keeps T_R1; iter loop W2 → R1 direct (no T_R1).
                        case (crn_ph)
                            4'd0: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_CRN_PAD + (crn_fi<<2));
                                pipe_ext_dout <= crn_fi; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_CRN_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (crn_fi+32'd1 == `LA_CRN_FILL) begin
                                        crn_a1 <= `LA_CRN_PAD + ((crn_a & `LA_CRN_MASK)<<2);
                                        crn_ph <= 4'd1; // T_R1 after fill only
                                    end else crn_fi <= crn_fi + 32'd1;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd1: begin // T_R1: WE#→OE# (fill → first R1)
                                crn_ph <= 4'd2;
                            end
                            4'd2: begin // R1
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= crn_a1[21:2];
                                if (wait_cnt >= `LA_CRN_RD_WAIT) begin
                                    crn_t <= (ext_data_in<<1) ^ (crn_a>>1);
                                    wait_cnt <= 3'd0; crn_ph <= 4'd4; // W1
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd4: begin // W1
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0; pipe_ext_addr <= crn_a1[21:2];
                                pipe_ext_dout <= crn_t ^ crn_b; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_CRN_WR_WAIT) begin
                                    crn_b <= crn_t;
                                    crn_a2 <= `LA_CRN_PAD + ((crn_t & `LA_CRN_MASK)<<2);
                                    wait_cnt <= 3'd0; crn_ph <= 4'd6; // R2
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd6: begin // R2
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= crn_a2[21:2];
                                if (wait_cnt >= `LA_CRN_RD_WAIT) begin
                                    crn_t2 <= ext_data_in;
                                    crn_a  <= crn_a + ($signed(crn_t) * $signed(ext_data_in));
                                    wait_cnt <= 3'd0; crn_ph <= 4'd8; // W2
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            default: begin // W2
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0; pipe_ext_addr <= crn_a2[21:2];
                                pipe_ext_dout <= crn_a; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_CRN_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (crn_it+32'd1 == `LA_CRN_ITERS) beat_q <= B_DONE;
                                    else begin
                                        crn_a  <= crn_a ^ crn_t2;
                                        crn_a1 <= `LA_CRN_PAD + (((crn_a ^ crn_t2) & `LA_CRN_MASK)<<2);
                                        crn_it <= crn_it + 32'd1;
                                        crn_ph <= 4'd2; // R1 direct (A2.75)
                                    end
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                        endcase
                    end else begin
                        // MIXED bit-accurate
                        case (mx_ph)
                            // 0: fill SRC[i] = (i^0x9e37)^(i<<3)
                            4'd0: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {14'b0, mx_i, 2'b00});
                                pipe_ext_dout <= mx_fill_val; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (mx_i == (`LA_MIX_WORDS - 16'd1)) begin
                                        mx_i <= 16'd0; mx_ph <= 4'd1;
                                    end else mx_i <= mx_i + 16'd1;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            // 1..4: stream load 4 words
                            4'd1: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {14'b0, mx_i, 2'b00});
                                if (wait_cnt >= `LA_EXT_RD_WAIT) begin
                                    mx_w0 <= ext_data_in; wait_cnt <= 3'd0; mx_ph <= 4'd2;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd2: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {14'b0, mx_i, 2'b00} + 32'd4);
                                if (wait_cnt >= `LA_EXT_RD_WAIT) begin
                                    mx_w1 <= ext_data_in; wait_cnt <= 3'd0; mx_ph <= 4'd3;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd3: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {14'b0, mx_i, 2'b00} + 32'd8);
                                if (wait_cnt >= `LA_EXT_RD_WAIT) begin
                                    mx_w2 <= ext_data_in; wait_cnt <= 3'd0; mx_ph <= 4'd4;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd4: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {14'b0, mx_i, 2'b00} + 32'd12);
                                if (wait_cnt >= `LA_EXT_RD_WAIT) begin
                                    mx_w3 <= ext_data_in;
                                    mx_s0 <= mx_s0 + mx_w0;
                                    mx_s1 <= mx_s1 ^ mx_w1;
                                    mx_s2 <= mx_s2 + mx_w2;
                                    mx_s3 <= mx_s3 ^ ext_data_in; // NBA: not mx_w3
                                    wait_cnt <= 3'd0; mx_ph <= 4'd5;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            // 5..8: stream store DST (use updated s*)
                            4'd5: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_DST + {14'b0, mx_i, 2'b00});
                                pipe_ext_dout <= mx_s0; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0; mx_ph <= 4'd6;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd6: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_DST + {14'b0, mx_i, 2'b00} + 32'd4);
                                pipe_ext_dout <= mx_s1; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0; mx_ph <= 4'd7;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd7: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_DST + {14'b0, mx_i, 2'b00} + 32'd8);
                                pipe_ext_dout <= mx_s2; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0; mx_ph <= 4'd8;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            4'd8: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_DST + {14'b0, mx_i, 2'b00} + 32'd12);
                                pipe_ext_dout <= mx_s3; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (mx_i + 16'd4 == `LA_MIX_WORDS) begin
                                        mx_t1 <= mx_s0 ^ mx_s1;
                                        mx_stride <= 16'h2000;
                                        mx_ph <= 4'd9;
                                    end else begin
                                        mx_i <= mx_i + 16'd4;
                                        mx_ph <= 4'd1;
                                    end
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            // 9: stride load SRC[t1 & 0x3fff]
                            4'd9: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_oe_n <= 1'b0; pipe_ext_we_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {(mx_t1[13:0]), 2'b00});
                                if (wait_cnt >= `LA_EXT_RD_WAIT) begin
                                    word_buf <= ext_data_in;
                                    wait_cnt <= 3'd0; mx_ph <= 4'd10;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            // 10: stride store new t1; update s0/s1
                            4'd10: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SRC + {(mx_t1[13:0]), 2'b00});
                                pipe_ext_dout <= mx_str_z; pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (mx_str_z[0])
                                        mx_s0 <= mx_s0 + word_buf;
                                    else
                                        mx_s1 <= mx_s1 ^ word_buf;
                                    mx_t1 <= mx_str_z;
                                    if (mx_stride == 16'd1) begin
                                        mx_sig <= 3'd0; mx_ph <= 4'd11;
                                    end else begin
                                        mx_stride <= mx_stride - 16'd1;
                                        mx_ph <= 4'd9;
                                    end
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                            // 11: SIG s0,s1,s2,s3,t1
                            default: begin
                                pipe_ext_ce_n <= 1'b0; pipe_ext_we_n <= 1'b0; pipe_ext_oe_n <= 1'b1;
                                pipe_ext_be_n <= 4'h0;
                                pipe_ext_addr <= wa(`LA_MIX_SIG + {27'b0, mx_sig, 2'b00});
                                case (mx_sig)
                                    3'd0: pipe_ext_dout <= mx_s0;
                                    3'd1: pipe_ext_dout <= mx_s1;
                                    3'd2: pipe_ext_dout <= mx_s2;
                                    3'd3: pipe_ext_dout <= mx_s3;
                                    default: pipe_ext_dout <= mx_t1;
                                endcase
                                pipe_ext_doe <= 1'b1;
                                if (wait_cnt >= `LA_EXT_WR_WAIT) begin
                                    wait_cnt <= 3'd0;
                                    if (mx_sig == 3'd4) beat_q <= B_DONE;
                                    else mx_sig <= mx_sig + 3'd1;
                                end else wait_cnt <= wait_cnt + 3'd1;
                            end
                        endcase
                    end
                end

                B_DONE: begin
                    pipe_port_sel <= 1'b0;
                    pipe_busy <= 1'b0;
                    pipe_done <= 1'b1;
                    pipe_retarget_pc <= `LA_PIPE_EPILOGUE_PC;
                    beat_q <= B_IDLE;
                end

                B_GIVEUP: begin
                    pipe_port_sel <= 1'b0;
                    pipe_busy <= 1'b0;
                    pipe_giveup <= 1'b1;
                    beat_q <= B_IDLE;
                end

                default: beat_q <= B_IDLE;
            endcase
        end
    end
endmodule
