module csr_file (
    input  wire        clk,
    input  wire        resetn,

    input  wire [13:0] csr_num,
    output reg  [31:0] csr_rdata,

    input  wire        csr_we,
    input  wire [13:0] csr_waddr,
    input  wire [31:0] csr_wdata,
    input  wire [31:0] csr_wmask,

    output wire [31:0] crmd,
    output wire [31:0] dmw0,
    output wire [31:0] dmw1
);
    localparam [13:0] CSR_CRMD = 14'h0000;
    localparam [13:0] CSR_DMW0 = 14'h0180;
    localparam [13:0] CSR_DMW1 = 14'h0181;

    reg [31:0] crmd_reg;
    reg [31:0] dmw0_reg;
    reg [31:0] dmw1_reg;

    always @(posedge clk) begin
        if (!resetn) begin
            crmd_reg <= 32'h0000_0008; // DA=1, PG=0
            dmw0_reg <= 32'd0;
            dmw1_reg <= 32'd0;
        end else if (csr_we) begin
            case (csr_waddr)
                CSR_CRMD: crmd_reg <= (crmd_reg & ~csr_wmask) | (csr_wdata & csr_wmask);
                CSR_DMW0: dmw0_reg <= (dmw0_reg & ~csr_wmask) | (csr_wdata & csr_wmask);
                CSR_DMW1: dmw1_reg <= (dmw1_reg & ~csr_wmask) | (csr_wdata & csr_wmask);
                default: begin end
            endcase
        end
    end

    always @(*) begin
        case (csr_num)
            CSR_CRMD: csr_rdata = crmd_reg;
            CSR_DMW0: csr_rdata = dmw0_reg;
            CSR_DMW1: csr_rdata = dmw1_reg;
            default:  csr_rdata = 32'd0;
        endcase
    end

    assign crmd = crmd_reg;
    assign dmw0 = dmw0_reg;
    assign dmw1 = dmw1_reg;
endmodule
