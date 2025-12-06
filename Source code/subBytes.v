`timescale 1ns / 1ps

module subBytes(
    input wire [127:0] in,
    output wire [127:0] out
);

    genvar i;
    generate
        for (i = 0; i < 128; i = i + 8) begin : sbox_loop
            sbox sbox_inst (
                .a(in[i+: 8]), 
                .c(out[i+: 8])
            );
        end
    endgenerate

endmodule
