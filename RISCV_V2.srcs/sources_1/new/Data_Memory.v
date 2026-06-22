`timescale 1ns / 1ps

module Data_Memory(
    input clk,
    input rst,
    input WE,
    input [31:0] WD,
    input [31:0] A,
    output [31:0] RD
);

    // 宣告深度為 1024 的記憶體
    reg [31:0] mem [0:1023];

    // 非同步讀取 (位址除以 4)
    assign RD = (rst) ? 32'h00000000 : mem[A[31:2]];

    // 同步寫入
    always @(posedge clk) begin
        if (WE) begin
            mem[A[31:2]] <= WD;
        end
    end

endmodule