`timescale 1ns / 1ps

module Top(
    input clk,
    input reset,           
    input [15:0] sw,
    input btn_score,       // T17 查詢分數按鈕 (右邊)
    input btn_u17,         // U17 當作拉桿按鈕 (下面)
    input btn_l,           // [新增] W19 左邊按鈕，用於查看倍率
    output RsTx,           // UART 傳送腳位 (連接到 USB)
    output [15:0] led,
    output [3:0] an,       
    output [6:0] seg       
);

    reg [17:0] clk_count;
    always @(posedge clk or posedge reset) begin
        if (reset) clk_count <= 18'd0;
        else       clk_count <= clk_count + 1'b1;
    end
    wire cpu_clk = clk_count[17]; 

    // ==========================================
    // 按鈕 U17 除彈跳與狀態翻轉 (Toggle)
    // ==========================================
    reg btn_sync1, btn_sync2, btn_prev;
    always @(posedge cpu_clk or posedge reset) begin
        if(reset) begin
            btn_sync1 <= 0; btn_sync2 <= 0; btn_prev <= 0;
        end else begin
            btn_sync1 <= btn_u17;
            btn_sync2 <= btn_sync1;
            btn_prev  <= btn_sync2;
        end
    end
    wire btn_edge = (btn_sync2 & ~btn_prev); // 偵測按下瞬間

    reg lever_state; // 這個變數會取代原本的 sw[0]
    always @(posedge cpu_clk or posedge reset) begin
        if (reset) lever_state <= 1'b0;
        else if (btn_edge) lever_state <= ~lever_state; // 按一下翻轉狀態
    end

    // ==========================================
    // 內部接線
    // ==========================================
    wire [31:0] cpu_address, cpu_write_data, cpu_read_data;
    wire mem_write;
    wire [31:0] ram_data_out, rng_data_out;
    wire led_en, ram_we, uart_we;
    wire [3:0] seg_en; 
    wire tx_ready_out;

    Single_Cycle_Top my_cpu (
        .clk(cpu_clk), .rst(reset),
        .mem_addr(cpu_address), .mem_wdata(cpu_write_data),
        .mem_rdata(cpu_read_data), .mem_write(mem_write)
    );

    Data_Memory my_data_ram (
        .clk(cpu_clk), .rst(reset), .WE(ram_we),               
        .WD(cpu_write_data), .A(cpu_address), .RD(ram_data_out)          
    );

    Address_Decoder my_decoder (
        .cpu_address(cpu_address), .mem_write(mem_write),
        .sw_in(sw), 
        .lever_in(lever_state),         // 傳入按鈕的翻轉狀態
        .btn_view_in(btn_l),            // [新增] 將左邊按鈕傳入查看倍率腳位
        .rng_data_in(rng_data_out), 
        .ram_data_in(ram_data_out),
        .tx_ready_in(tx_ready_out),     // 傳入 UART 狀態
        .data_to_cpu(cpu_read_data),
        .led_enable(led_en), 
        .seg_enable(seg_en), 
        .ram_write_enable(ram_we),
        .uart_write_enable(uart_we)     // 輸出寫入 UART 的致能訊號
    );

    // ==========================================
    // 周邊模組
    // ==========================================
    reg [15:0] led_reg;
    always @(posedge cpu_clk or posedge reset) begin
        if (reset) led_reg <= 16'd50;
        else if (led_en) led_reg <= cpu_write_data[15:0];
    end
    assign led = led_reg;

    reg [3:0] vram_d0, vram_d1, vram_d2, vram_d3;
    always @(posedge cpu_clk or posedge reset) begin
        if (reset) begin
            // [修改] 將 vram_d3 初始值也設為 4'hC，開機時四格都會顯示 C (一橫線或空白)
            vram_d0 <= 4'hC; vram_d1 <= 4'hC; vram_d2 <= 4'hC; vram_d3 <= 4'hC; 
        end else begin
            if (seg_en[0]) vram_d0 <= cpu_write_data[3:0];
            if (seg_en[1]) vram_d1 <= cpu_write_data[3:0];
            if (seg_en[2]) vram_d2 <= cpu_write_data[3:0];
            if (seg_en[3]) vram_d3 <= cpu_write_data[3:0];
        end
    end
    
    wire [3:0] score_thou = (led_reg / 1000) % 10;
    wire [3:0] score_hund = (led_reg / 100)  % 10;
    wire [3:0] score_tens = (led_reg / 10)   % 10;
    wire [3:0] score_ones = (led_reg)        % 10;
    
    wire [15:0] score_disp = {score_thou, score_hund, score_tens, score_ones};
    wire [15:0] game_disp  = {vram_d3, vram_d2, vram_d1, vram_d0};
    wire [15:0] final_disp = btn_score ? score_disp : game_disp;

    SevenSegCtrl my_seven_seg (
        .clk(clk), .rst(reset),
        .disp_data(final_disp),
        .an(an), .seg(seg)
    );

    wire rng_rst_n = ~reset;
    RNG my_rng (
        .clk(clk), .rst_n(rng_rst_n), .out_data(rng_data_out)
    );

    // ==========================================
    // UART 傳送模組 - 修復重複列印 Bug
    // ==========================================
    reg prev_uart_we;
    reg tx_start_pulse;
    always @(posedge clk) begin
        prev_uart_we <= (uart_we && cpu_clk);
        tx_start_pulse <= (uart_we && cpu_clk) && !prev_uart_we;
    end

    UART_TX my_uart_tx (
        .clk(clk),              
        .reset(reset),
        .tx_start(tx_start_pulse),           
        .tx_data(cpu_write_data[7:0]),       
        .tx(RsTx),                           
        .tx_ready(tx_ready_out)              
    );

endmodule