module forward_ctrl (
    // 当前 ID 阶段需要读取的寄存器编号
    input  wire [ 4:0] id_rs1,
    input  wire [ 4:0] id_rs2,

    // --- 1. 来自 EX 阶段的前递信息 (距离最近，优先级最高) ---
    input  wire        ex_we,
    input  wire [ 4:0] ex_waddr,
    input  wire [31:0] ex_fw_data,  // EX 阶段算出的最新结果

    // --- 2. 来自 MEM 阶段的前递信息 (次优先级) ---
    input  wire        mem_we,
    input  wire [ 4:0] mem_waddr,
    input  wire [31:0] mem_fw_data, // MEM 阶段准备写回的结果

    // --- 3. 来自 WB 阶段的前递信息 (最低优先级) ---
    input  wire        wb_we,
    input  wire [ 4:0] wb_waddr,
    input  wire [31:0] wb_fw_data,  // 马上要写入 RegFile 的最终数据

    // 原始从 RegFile 读出的旧数据
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,

    // 经过“安检站”拦截替换后，真正安全的数据
    output wire [31:0] id_fwd_rdata1,
    output wire [31:0] id_fwd_rdata2
);

    // 对于 rs1 的前递判定：注意 0 号寄存器 ($r0) 永远不能被前递
    assign id_fwd_rdata1 = 
        (ex_we  && (ex_waddr != 5'd0)  && (ex_waddr == id_rs1)) ? ex_fw_data  :
        (mem_we && (mem_waddr != 5'd0) && (mem_waddr == id_rs1)) ? mem_fw_data :
        (wb_we  && (wb_waddr != 5'd0)  && (wb_waddr == id_rs1)) ? wb_fw_data  :
        rf_rdata1; // 没有冲突，乖乖用寄存器堆里的旧数据

    // 对于 rs2 的前递判定
    assign id_fwd_rdata2 = 
        (ex_we  && (ex_waddr != 5'd0)  && (ex_waddr == id_rs2)) ? ex_fw_data  :
        (mem_we && (mem_waddr != 5'd0) && (mem_waddr == id_rs2)) ? mem_fw_data :
        (wb_we  && (wb_waddr != 5'd0)  && (wb_waddr == id_rs2)) ? wb_fw_data  :
        rf_rdata2;

endmodule