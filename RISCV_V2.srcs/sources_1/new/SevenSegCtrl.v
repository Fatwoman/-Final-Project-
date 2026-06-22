`timescale 1ns / 1ps

module SevenSegCtrl (
    input  wire        clk,       // 使用 100MHz 高速時脈進行掃描
    input  wire        rst,       
    input  wire [15:0] disp_data, // CPU 送來的 16-bit 顯示資料
    output reg  [3:0]  an,        
    output reg  [6:0]  seg        
);

    // 掃描計數器
    reg [19:0] scan_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) scan_cnt <= 0;
        else     scan_cnt <= scan_cnt + 1;
    end
    
    wire [1:0] scan_select = scan_cnt[19:18];
    reg [3:0] current_digit_val; 

    // 位數多工器
    always @(*) begin
        case (scan_select)
            2'b00: begin an = 4'b1110; current_digit_val = disp_data[3:0];   end
            2'b01: begin an = 4'b1101; current_digit_val = disp_data[7:4];   end
            2'b10: begin an = 4'b1011; current_digit_val = disp_data[11:8];  end
            2'b11: begin an = 4'b0111; current_digit_val = disp_data[15:12]; end
            default: begin an = 4'b1111; current_digit_val = 4'h0; end
        endcase
        
        // [新增] 限幅邏輯：如果數字 > 9，強制歸零 (或是你也可以設為其他值)
        if (current_digit_val > 4'd9) begin
            current_digit_val = 4'd0; 
        end
    end
 
    // 硬刻 ROM 查表 (防呆設計，避免檔案路徑錯誤)
    always @(*) begin
        case (current_digit_val)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b1100001; // Upper U (原代碼 11)
            4'hC: seg = 7'b0111111; // Dash -  (原代碼 12)
            default: seg = 7'b1111111; // 全暗
        endcase
    end
endmodule