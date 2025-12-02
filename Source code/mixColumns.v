`timescale 1ns / 1ps

module mixColumns(
    input wire [127:0] state_in,
    output wire [127:0] state_out
);

    function [7:0] mb2;
        input [7:0] x;
        begin 
            mb2 = (x[7] == 1) ? ((x << 1) ^ 8'h1b) : (x << 1);
        end
    endfunction

    function [7:0] mb3;
        input [7:0] x;
        begin 
            mb3 = mb2(x) ^ x;
        end
    endfunction

    genvar i;
    generate 
        for (i = 0; i < 4; i = i + 1) begin : m_col
            
            assign state_out[(i*32+24) +: 8] = 
                mb2(state_in[(i*32+24) +: 8]) ^ 
                mb3(state_in[(i*32+16) +: 8]) ^ 
                state_in[(i*32+8) +: 8]       ^ 
                state_in[i*32 +: 8];

            assign state_out[(i*32+16) +: 8] = 
                state_in[(i*32+24) +: 8]      ^ 
                mb2(state_in[(i*32+16) +: 8]) ^ 
                mb3(state_in[(i*32+8) +: 8])  ^ 
                state_in[i*32 +: 8];

            assign state_out[(i*32+8) +: 8] = 
                state_in[(i*32+24) +: 8]      ^ 
                state_in[(i*32+16) +: 8]      ^ 
                mb2(state_in[(i*32+8) +: 8])  ^ 
                mb3(state_in[i*32 +: 8]);

            assign state_out[i*32 +: 8] = 
                mb3(state_in[(i*32+24) +: 8]) ^ 
                state_in[(i*32+16) +: 8]      ^ 
                state_in[(i*32+8) +: 8]       ^ 
                mb2(state_in[i*32 +: 8]);
        end
    endgenerate

endmodule