`timescale 1ns / 1ps

module AES_tb();

reg clk;
reg reset;
reg start;
reg [127:0] plaintext;
reg [255:0] key;
wire [127:0] ciphertext;
wire done;

reg [255:0] kat_key = 256'h8000000000000000000000000000000000000000000000000000000000000000;
reg [127:0] kat_plaintext = 128'h00000000000000000000000000000000;
reg [127:0] kat_expected_ciphertext = 128'he35a6dcb19b201a01ebcfa8aa22b5759;

AES dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .plaintext(plaintext),
    .key(key),
    .ciphertext(ciphertext),
    .done(done)
);

initial begin
    clk = 0;
    forever #4 clk = ~clk;
end

initial begin
    reset = 1;
    start = 0;
    plaintext = 0;
    key = 0;
    #10;
    reset = 0;
    #10;

    plaintext = kat_plaintext;
    key = kat_key;
        
    $display("Plaintext: %h", plaintext);
    $display("Key:       %h", key);

    @(posedge clk);
    start = 1;
        
    @(posedge clk);
    start = 0;

    wait (done == 1);
        
    $display("Expected Ciphertext: %h", kat_expected_ciphertext);
    $display("Actual Ciphertext:   %h", ciphertext);
        
    if (ciphertext == kat_expected_ciphertext) begin
        $display("TEST PASSED!");
    end else begin
        $display("TEST FAILED!");
    end

    #100;
    $finish;
end

endmodule