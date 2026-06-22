`timescale 1ns / 1ps

module tb_Top();
    reg clk;
    reg reset;
    reg [15:0] sw;
    wire [15:0] led;

    // 呼叫你的 Top 模組
    Top uut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .led(led)
    );

    // 產生 100MHz 虛擬時脈
    always #5 clk = ~clk;

    initial begin
        // 1. 初始狀態：按下 Reset，Switch 全歸零
        clk = 0;
        reset = 1;
        sw = 16'd0;
        
        // 2. 等待 100 奈秒後，放開 Reset 讓 CPU 啟動
        #100;
        reset = 0;
        
        // 3. 讓它跑一段時間看 LED 0 有沒有亮 (0+1=1)
        #200;
        
        // 4. 模擬手動將 Switch 0 往上撥
        sw = 16'd1;
        
        // 5. 觀察 LED 是不是變成 2
        #200;
        
        $finish; // 結束模擬
    end
endmodule