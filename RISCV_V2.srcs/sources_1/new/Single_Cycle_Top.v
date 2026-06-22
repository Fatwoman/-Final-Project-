`timescale 1ns / 1ps

module Single_Cycle_Top(
    input clk,
    input rst,
    output [31:0] mem_addr,   
    output [31:0] mem_wdata,  
    input  [31:0] mem_rdata,  
    output mem_write          
);

    // =========================================================
    // [內建組譯器] - FPGA 組合語言編譯引擎
    // =========================================================
    function [31:0] asm_addi(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        asm_addi = {imm, rs1, 3'b000, rd, 7'h13};
    endfunction
    function [31:0] asm_lw(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        asm_lw = {imm, rs1, 3'b010, rd, 7'h03};
    endfunction
    function [31:0] asm_sw(input [4:0] rs2, input [4:0] rs1, input [11:0] imm);
        asm_sw = {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'h23};
    endfunction
    function [31:0] asm_beq(input [4:0] rs1, input [4:0] rs2, input [12:0] imm);
        asm_beq = {imm[12], imm[10:5], rs2, rs1, 3'b000, imm[4:1], imm[11], 7'h63};
    endfunction
    function [31:0] asm_sub(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_sub = {7'b0100000, rs2, rs1, 3'b000, rd, 7'h33};
    endfunction
    function [31:0] asm_add(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'h33};
    endfunction

    reg [31:0] PC;
    wire [31:0] PCNext, PCTarget, PCPlus4;
    
    always @(posedge clk or posedge rst) begin
        if (rst) PC <= 32'h00000000;
        else     PC <= PCNext;
    end
    assign PCPlus4 = PC + 4;

    // ====================================================
    // 老虎機核心邏輯 (4數字 / 複雜倍率 / 按鈕查看版)
    // ====================================================
    wire [29:0] word_addr = PC[31:2];
    reg [31:0] Instr;
    
    always @(*) begin
        if (rst) begin
            Instr = 32'h00000000;
        end else begin
            case (word_addr)
                // --- 0. 系統初始化 ---
                30'd0: Instr = asm_addi(10, 0, 2000); // 基準位址 x10 = 2000
                30'd1: Instr = asm_addi(20, 0, 50);   // 初始分數 x20 = 50
                30'd2: Instr = asm_addi(27, 0, 0);    // 自動計數器 x27 = 0
                30'd3: Instr = asm_addi(5,  0, 1);    // 比較常數 x5 = 1

                // --- 1. 模式判定與啟動迴圈起點 ---
                30'd4: Instr = asm_lw(6, 10, 0);      // 讀取拉桿 U17 (x6)
                30'd5: Instr = asm_lw(7, 10, 40);     // 讀取 SW15 Auto Mode (x7)
                30'd6: Instr = asm_lw(25, 10, 56);    // 讀取 btn_l 左按鈕 (x25)

                // 自動模式初始化攔截
                30'd7: Instr = asm_beq(7, 0, 16);     // 若手動模式 (SW15=0)，跳過自動設定 (跳至指令 11)
                30'd8: Instr = asm_beq(27, 0, 8);     // 若自動計數器=0，跳去設定次數 (跳至指令 10)
                30'd9: Instr = asm_beq(0, 0, 8);      // 若還在連抽中，跳過設定 (跳至指令 11)
                30'd10:Instr = asm_addi(27, 0, 1000); // [設定] x27 = 1000 次

                // --- 2. 顯示切換邏輯 (查看倍率 vs 待機亂數) ---
                30'd11:Instr = asm_beq(25, 0, 32);    // 若 btn_l 沒按，跳去顯示正常亂數 (跳至指令 19)
                
                // [按住 btn_l：顯示倍率 000X]
                30'd12:Instr = asm_lw(23, 10, 52);    // 讀取 bet_val
                30'd13:Instr = asm_sw(23, 10, 24);    // 顯示在 Seg0
                30'd14:Instr = asm_sw(0, 10, 28);     // Seg1 顯示 0
                30'd15:Instr = asm_sw(0, 10, 32);     // Seg2 顯示 0
                30'd16:Instr = asm_sw(0, 10, 36);     // Seg3 顯示 0
                30'd17:Instr = asm_addi(0, 0, 0);     // 軟體延遲
                30'd18:Instr = asm_beq(0, 0, 48);     // 略過亂數滾動，直接跳去停止檢查 (跳至指令 30)

                // --- 3. 正常亂數滾動顯示 (4個數字) ---
                30'd19:Instr = asm_lw(11, 10, 8);  30'd20:Instr = asm_sw(11, 10, 24); // 讀寫 D0
                30'd21:Instr = asm_lw(12, 10, 12); 30'd22:Instr = asm_sw(12, 10, 28); // 讀寫 D1
                30'd23:Instr = asm_lw(13, 10, 16); 30'd24:Instr = asm_sw(13, 10, 32); // 讀寫 D2
                30'd25:Instr = asm_lw(14, 10, 20); 30'd26:Instr = asm_sw(14, 10, 36); // 讀寫 D3
                30'd27:Instr = asm_addi(0, 0, 0);  30'd28:Instr = asm_addi(0, 0, 0);  30'd29:Instr = asm_addi(0, 0, 0);

                // --- 4. 停止條件檢查 ---
                30'd30:Instr = asm_beq(7, 0, 8);      // 若手動模式 (SW15=0)，去檢查 U17 (跳至指令 32)
                30'd31:Instr = asm_beq(0, 0, 12);     // 自動模式，無條件直接停止並對獎 (跳至指令 34)
                
                // 手動模式判斷
                30'd32:Instr = asm_beq(6, 0, -112);   // [關鍵] 若 U17=0，維持滾動，跳回起點 (跳至指令 4)
                30'd33:Instr = asm_beq(0, 0, 4);      // 若 U17=1，停止滾動 (跳至指令 34)

                // --- 5. 凍結畫面與扣款 ---
                30'd34:Instr = asm_sw(11, 10, 24);    // 凍結 D0
                30'd35:Instr = asm_sw(12, 10, 28);    // 凍結 D1
                30'd36:Instr = asm_sw(13, 10, 32);    // 凍結 D2
                30'd37:Instr = asm_sw(14, 10, 36);    // 凍結 D3
                30'd38:Instr = asm_lw(23, 10, 52);    // 讀取 bet_val (x23)
                30'd39:Instr = asm_sub(20, 20, 23);   // 總分先扣除下注金

                // --- 6. 獎項配對計數演算法 (Pair Counting) ---
                30'd40:Instr = asm_addi(22, 0, 0);    // x22 = 0 (相同配對數計數器)
                
                // 配對 D0-D1
                30'd41:Instr = asm_sub(4, 11, 12); 30'd42:Instr = asm_beq(4, 0, 8); 30'd43:Instr = asm_beq(0, 0, 8); 30'd44:Instr = asm_addi(22, 22, 1);
                // 配對 D0-D2
                30'd45:Instr = asm_sub(4, 11, 13); 30'd46:Instr = asm_beq(4, 0, 8); 30'd47:Instr = asm_beq(0, 0, 8); 30'd48:Instr = asm_addi(22, 22, 1);
                // 配對 D0-D3
                30'd49:Instr = asm_sub(4, 11, 14); 30'd50:Instr = asm_beq(4, 0, 8); 30'd51:Instr = asm_beq(0, 0, 8); 30'd52:Instr = asm_addi(22, 22, 1);
                // 配對 D1-D2
                30'd53:Instr = asm_sub(4, 12, 13); 30'd54:Instr = asm_beq(4, 0, 8); 30'd55:Instr = asm_beq(0, 0, 8); 30'd56:Instr = asm_addi(22, 22, 1);
                // 配對 D1-D3
                30'd57:Instr = asm_sub(4, 12, 14); 30'd58:Instr = asm_beq(4, 0, 8); 30'd59:Instr = asm_beq(0, 0, 8); 30'd60:Instr = asm_addi(22, 22, 1);
                // 配對 D2-D3
                30'd61:Instr = asm_sub(4, 13, 14); 30'd62:Instr = asm_beq(4, 0, 8); 30'd63:Instr = asm_beq(0, 0, 8); 30'd64:Instr = asm_addi(22, 22, 1);

                // --- 7. 依據配對數決定倍率 (存入 x24) ---
                30'd65:Instr = asm_addi(24, 0, 0);    // 預設倍率 x24 = 0
                30'd66:Instr = asm_addi(4, 0, 6);  30'd67:Instr = asm_beq(22, 4, 36); // 若 6配對(4同) -> 跳至 x50 (指令 76)
                30'd68:Instr = asm_addi(4, 0, 3);  30'd69:Instr = asm_beq(22, 4, 36); // 若 3配對(3同) -> 跳至 x20 (指令 78)
                30'd70:Instr = asm_addi(4, 0, 2);  30'd71:Instr = asm_beq(22, 4, 36); // 若 2配對(2對同) -> 跳至 x10 (指令 80)
                30'd72:Instr = asm_addi(4, 0, 1);  30'd73:Instr = asm_beq(22, 4, 28); // 若 1配對(2同) -> 跳至 x10 (指令 80)
                30'd74:Instr = asm_beq(0, 0, 28);     // 若 0配對(沒中獎) -> 跳去加分迴圈 (指令 81)
                30'd75:Instr = asm_addi(0, 0, 0);     // 結構對齊用

                30'd76:Instr = asm_addi(24, 0, 50); 30'd77:Instr = asm_beq(0, 0, 16); // 設為 x50，跳到 81
                30'd78:Instr = asm_addi(24, 0, 20); 30'd79:Instr = asm_beq(0, 0, 8);  // 設為 x20，跳到 81
                30'd80:Instr = asm_addi(24, 0, 10);                                   // 設為 x10，進入 81

                // --- 8. 倍率乘法加分迴圈 ---
                30'd81:Instr = asm_beq(24, 0, 16);    // 若倍率=0，結束加分 (跳至指令 85)
                30'd82:Instr = asm_add(20, 20, 23);   // score += bet_val
                30'd83:Instr = asm_addi(24, 24, -1);  // 倍率 -= 1
                30'd84:Instr = asm_beq(0, 0, -12);    // 迴圈跳回指令 81

                // --- 9. 儲存狀態與顯示分數 ---
                30'd85:Instr = asm_addi(21, 0, 0);    // 預設狀態 x21=0 (Lose)
                30'd86:Instr = asm_beq(22, 0, 8);     // 若沒中獎，跳過 Win 設定 (跳至指令 88)
                30'd87:Instr = asm_addi(21, 0, 1);    // 有中獎，設 x21=1 (Win)
                30'd88:Instr = asm_sw(20, 10, 4);     // 寫回最新總分到記憶體

                // ================================================
                // --- 10. UART 發送格式：[D3,D2,D1,D0,W/L] ---
                // ================================================
                30'd89:Instr = asm_addi(31, 0, 91);   // '['
                30'd90:Instr = asm_lw(30, 10, 44); 30'd91:Instr = asm_beq(30, 0, -4); 30'd92:Instr = asm_sw(31, 10, 48);

                30'd93:Instr = asm_addi(31, 14, 48);  // 發送 D3 (x14)
                30'd94:Instr = asm_lw(30, 10, 44); 30'd95:Instr = asm_beq(30, 0, -4); 30'd96:Instr = asm_sw(31, 10, 48);

                30'd97:Instr = asm_addi(31, 0, 44);   // ','
                30'd98:Instr = asm_lw(30, 10, 44); 30'd99:Instr = asm_beq(30, 0, -4); 30'd100:Instr = asm_sw(31, 10, 48);

                30'd101:Instr = asm_addi(31, 13, 48); // 發送 D2 (x13)
                30'd102:Instr = asm_lw(30, 10, 44); 30'd103:Instr = asm_beq(30, 0, -4); 30'd104:Instr = asm_sw(31, 10, 48);

                30'd105:Instr = asm_addi(31, 0, 44);  // ','
                30'd106:Instr = asm_lw(30, 10, 44); 30'd107:Instr = asm_beq(30, 0, -4); 30'd108:Instr = asm_sw(31, 10, 48);

                30'd109:Instr = asm_addi(31, 12, 48); // 發送 D1 (x12)
                30'd110:Instr = asm_lw(30, 10, 44); 30'd111:Instr = asm_beq(30, 0, -4); 30'd112:Instr = asm_sw(31, 10, 48);

                30'd113:Instr = asm_addi(31, 0, 44);  // ','
                30'd114:Instr = asm_lw(30, 10, 44); 30'd115:Instr = asm_beq(30, 0, -4); 30'd116:Instr = asm_sw(31, 10, 48);

                30'd117:Instr = asm_addi(31, 11, 48); // 發送 D0 (x11)
                30'd118:Instr = asm_lw(30, 10, 44); 30'd119:Instr = asm_beq(30, 0, -4); 30'd120:Instr = asm_sw(31, 10, 48);

                30'd121:Instr = asm_addi(31, 0, 44);  // ','
                30'd122:Instr = asm_lw(30, 10, 44); 30'd123:Instr = asm_beq(30, 0, -4); 30'd124:Instr = asm_sw(31, 10, 48);

                // --- 輸贏字串判定 ---
                30'd125:Instr = asm_beq(21, 0, 60);   // 若 Lose (x21=0)，跳到 LOSE 區塊 (指令 140)

                // [WIN]
                30'd126:Instr = asm_addi(31, 0, 119); // 'w'
                30'd127:Instr = asm_lw(30, 10, 44); 30'd128:Instr = asm_beq(30, 0, -4); 30'd129:Instr = asm_sw(31, 10, 48);
                30'd130:Instr = asm_addi(31, 0, 105); // 'i'
                30'd131:Instr = asm_lw(30, 10, 44); 30'd132:Instr = asm_beq(30, 0, -4); 30'd133:Instr = asm_sw(31, 10, 48);
                30'd134:Instr = asm_addi(31, 0, 110); // 'n'
                30'd135:Instr = asm_lw(30, 10, 44); 30'd136:Instr = asm_beq(30, 0, -4); 30'd137:Instr = asm_sw(31, 10, 48);
                30'd138:Instr = asm_beq(0, 0, 72);    // 印完 WIN 跳過 LOSE (跳到指令 156)
                30'd139:Instr = asm_addi(0, 0, 0);    // 空位對齊

                // [LOSE]
                30'd140:Instr = asm_addi(31, 0, 108); // 'l'
                30'd141:Instr = asm_lw(30, 10, 44); 30'd142:Instr = asm_beq(30, 0, -4); 30'd143:Instr = asm_sw(31, 10, 48);
                30'd144:Instr = asm_addi(31, 0, 111); // 'o'
                30'd145:Instr = asm_lw(30, 10, 44); 30'd146:Instr = asm_beq(30, 0, -4); 30'd147:Instr = asm_sw(31, 10, 48);
                30'd148:Instr = asm_addi(31, 0, 115); // 's'
                30'd149:Instr = asm_lw(30, 10, 44); 30'd150:Instr = asm_beq(30, 0, -4); 30'd151:Instr = asm_sw(31, 10, 48);
                30'd152:Instr = asm_addi(31, 0, 101); // 'e'
                30'd153:Instr = asm_lw(30, 10, 44); 30'd154:Instr = asm_beq(30, 0, -4); 30'd155:Instr = asm_sw(31, 10, 48);

                // --- 換行結尾 ---
                30'd156:Instr = asm_addi(31, 0, 93);  // ']'
                30'd157:Instr = asm_lw(30, 10, 44); 30'd158:Instr = asm_beq(30, 0, -4); 30'd159:Instr = asm_sw(31, 10, 48);
                30'd160:Instr = asm_addi(31, 0, 10);  // '\n'
                30'd161:Instr = asm_lw(30, 10, 44); 30'd162:Instr = asm_beq(30, 0, -4); 30'd163:Instr = asm_sw(31, 10, 48);

                // ====================================================
                // --- 11. 結算重啟機制 ---
                // ====================================================
                30'd164:Instr = asm_beq(27, 0, 12);   // 若是手動模式，跳去等待按鈕放開 (指令 167)
                30'd165:Instr = asm_addi(27, 27, -1); // [自動模式] 計數器--
                30'd166:Instr = asm_beq(0, 0, -648);  // 自動模式繼續狂抽！(跳回指令 4)

                30'd167:Instr = asm_lw(6, 10, 0);     // [手動模式] 讀取 U17 按鈕
                30'd168:Instr = asm_beq(6, 5, -4);    // 若還按著 (U17=1)，原地卡死 (跳回指令 167)
                30'd169:Instr = asm_beq(0, 0, -660);  // 若放開了，跳回起點重新滾動 (跳回指令 4)

                default: Instr = 32'h00000000;
            endcase
        end
    end

    // ==========================================
    // 3. Control Unit 與硬體架構 (完全保留)
    // ==========================================
    wire is_lw   = (Instr[6:0] == 7'h03);
    wire is_sw   = (Instr[6:0] == 7'h23);
    wire is_addi = (Instr[6:0] == 7'h13);
    wire is_R    = (Instr[6:0] == 7'h33); 
    wire is_sub  = is_R && (Instr[31:25] == 7'h20);
    wire is_beq  = (Instr[6:0] == 7'h63);

    wire RegWrite  = is_lw | is_addi | is_R;
    wire ALUSrc    = is_lw | is_sw | is_addi;
    wire MemWrite  = is_sw;
    wire ResultSrc = is_lw;
    wire Branch    = is_beq;
    wire [1:0] ImmSrc = is_sw ? 2'b01 : (is_beq ? 2'b10 : 2'b00);

    reg [31:0] rf [0:31];
    wire [31:0] Result;
    integer k;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k=0; k<32; k=k+1) rf[k] <= 0;
        end else if (RegWrite && Instr[11:7] != 0) begin
            rf[Instr[11:7]] <= Result;
        end
    end
    
    wire [31:0] RD1 = (Instr[19:15] != 0) ? rf[Instr[19:15]] : 0;
    wire [31:0] RD2 = (Instr[24:20] != 0) ? rf[Instr[24:20]] : 0;

    reg [31:0] ImmExt;
    always @(*) begin
        case(ImmSrc)
            2'b00: ImmExt = {{20{Instr[31]}}, Instr[31:20]}; 
            2'b01: ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]}; 
            2'b10: ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0}; 
            default: ImmExt = 32'b0;
        endcase
    end

    wire [31:0] SrcA = RD1;
    wire [31:0] SrcB = ALUSrc ? ImmExt : RD2;
    wire [31:0] ALUResult = (Branch | is_sub) ? (SrcA - SrcB) : (SrcA + SrcB); 
    wire Zero = (ALUResult == 0);

    assign PCTarget = PC + ImmExt;
    wire PCSrc = Branch & Zero;
    assign PCNext = PCSrc ? PCTarget : PCPlus4;

    assign mem_addr  = ALUResult;
    assign mem_wdata = RD2;
    assign mem_write = MemWrite;
    assign Result    = ResultSrc ? mem_rdata : ALUResult;

endmodule