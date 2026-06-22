`timescale 1ns / 1ps

module RNG (
    input  wire        clk,   
    input  wire        rst_n,    
    output wire [31:0] out_data  
);
    // LFSR
    reg [42:0] lfsr_reg;
    wire       lfsr_feedback;
    assign lfsr_feedback = lfsr_reg[42] ^ lfsr_reg[40] ^ lfsr_reg[19] ^ lfsr_reg[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr_reg <= 43'h1;
        else        lfsr_reg <= {lfsr_reg[41:0], lfsr_feedback};
    end

    // CASR
    reg [36:0] casr_reg;        
    reg [36:0] next_casr_state;
    integer i;
    reg left, right;  

    always @(*) begin
        for (i = 0; i < 37; i = i + 1) begin
            if (i == 0)  right = 1'b0; else right = casr_reg[i-1];
            if (i == 36) left = 1'b0;  else left = casr_reg[i+1];
            if (i == 28) next_casr_state[i] = left ^ casr_reg[i] ^ right;
            else         next_casr_state[i] = left ^ right;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) casr_reg <= 37'h1AAAA_AAAA;
        else        casr_reg <= next_casr_state;
    end
   
    assign out_data = lfsr_reg[31:0] ^ casr_reg[31:0];
endmodule