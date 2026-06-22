`timescale 1ns / 1ps

module UART_TX #(
    parameter CLKS_PER_BIT = 868 // 100MHz / 115200 baud rate = 868
)(
    input clk,
    input reset,
    input tx_start,        // CPU 通知開始傳送
    input [7:0] tx_data,   // CPU 要傳送的 8-bit ASCII 字元
    output reg tx,         // 實際連接到 USB 的實體線路
    output reg tx_ready    // 告訴 CPU 我現在有空 (=1) 還是忙碌 (=0)
);

    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state = IDLE;
    reg [9:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] tx_data_reg = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1'b1; // UART 預設高電位
            tx_ready <= 1'b1;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_start) begin
                        tx_ready <= 1'b0;       // 標記忙碌
                        tx_data_reg <= tx_data; // 鎖存資料
                        state <= START;
                    end
                end
                START: begin
                    tx <= 1'b0; // Start bit
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end
                DATA: begin
                    tx <= tx_data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_index < 7) bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end
                STOP: begin
                    tx <= 1'b1; // Stop bit
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule