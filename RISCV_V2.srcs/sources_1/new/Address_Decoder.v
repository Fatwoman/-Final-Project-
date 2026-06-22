`timescale 1ns / 1ps

module Address_Decoder(
    input [31:0] cpu_address,   
    input mem_write,            
    
    input [15:0] sw_in,         
    input lever_in,             // 接收按鈕切換狀態 (U17 拉桿)
    input btn_view_in,          // [新增] 接收查看倍率按鈕狀態 (btn_l)
    input [31:0] rng_data_in,   
    input [31:0] ram_data_in,   
    input tx_ready_in,          // 接收 UART 的狀態旗標
    
    output reg [31:0] data_to_cpu,   
    output reg led_enable,           
    output reg [3:0] seg_enable,     
    output reg ram_write_enable,     
    output reg uart_write_enable     // 寫入 UART 發送暫存器
);

    // [修改] 提取 4 個亂數，並新增 digit3
    wire [31:0] digit0 = (rng_data_in[9:0]   % 10);
    wire [31:0] digit1 = (rng_data_in[19:10] % 10);
    wire [31:0] digit2 = (rng_data_in[29:20] % 10);
    wire [31:0] digit3 = (rng_data_in[31:22] % 10); // [新增] 萃取第 4 個隨機數字

    reg [31:0] bet_val;
    always @(*) begin
        case (sw_in[2:1])
            2'b00: bet_val = 32'd1;
            2'b01: bet_val = 32'd2;
            2'b10: bet_val = 32'd3;
            2'b11: bet_val = 32'd5;
            default: bet_val = 32'd1;
        endcase
    end

    // 格式化輸入資料給 CPU
    wire [31:0] lever_status = {31'b0, lever_in};
    wire [31:0] uart_status  = {31'b0, tx_ready_in}; 
    wire [31:0] view_status  = {31'b0, btn_view_in}; // [新增] 倍率查看按鈕狀態格式化

    always @(*) begin
        data_to_cpu = ram_data_in; 
        led_enable = 1'b0;
        seg_enable = 4'b0000;
        ram_write_enable = 1'b0;
        uart_write_enable = 1'b0;

        // --- 讀取地圖 (Read) ---
        if      (cpu_address == 32'd2000) data_to_cpu = lever_status; // 讀取拉桿
        else if (cpu_address == 32'd2008) data_to_cpu = digit0;       // 讀取亂數 0
        else if (cpu_address == 32'd2012) data_to_cpu = digit1;       // 讀取亂數 1
        else if (cpu_address == 32'd2016) data_to_cpu = digit2;       // 讀取亂數 2
        else if (cpu_address == 32'd2020) data_to_cpu = digit3;       // [新增] 讀取亂數 3
        else if (cpu_address == 32'd2040) data_to_cpu = {31'b0, sw_in[15]}; // 讀取 Switch 15 (自動模式開關)
        else if (cpu_address == 32'd2044) data_to_cpu = uart_status;  // 讀取 UART Tx_ready 狀態
        else if (cpu_address == 32'd2052) data_to_cpu = bet_val;      // [修改] 下注金移至 2052，讓位給 digit3
        else if (cpu_address == 32'd2056) data_to_cpu = view_status;  // [新增] 讀取查看倍率按鈕

        // --- 寫入地圖 (Write) ---
        if (mem_write) begin
            if      (cpu_address == 32'd2004) led_enable = 1'b1;       
            else if (cpu_address == 32'd2024) seg_enable = 4'b0001;    
            else if (cpu_address == 32'd2028) seg_enable = 4'b0010;    
            else if (cpu_address == 32'd2032) seg_enable = 4'b0100;    
            else if (cpu_address == 32'd2036) seg_enable = 4'b1000;    
            else if (cpu_address == 32'd2048) uart_write_enable = 1'b1; // 寫入資料到 UART
            else ram_write_enable = 1'b1;
        end
    end
endmodule