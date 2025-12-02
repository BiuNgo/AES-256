`timescale 1ns / 1ps

module AES(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [127:0] plaintext,
    input wire [255:0] key,
    output wire [127:0] ciphertext,
    output wire done
);

    AES_Encrypt aes_encrypt_inst(
        .clk(clk),
        .reset(reset),
        .start(start),
        .in(plaintext),
        .key(key),
        .out(ciphertext),
        .done(done)
    );

endmodule