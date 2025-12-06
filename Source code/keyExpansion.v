`timescale 1ns / 1ps

module keyExpansion (
    input wire clk,
    input wire reset,
    input wire enable_round,
    input wire [255:0] key_in,
    input wire [3:0] round_num,
    output wire [127:0] round_key_out
);

    reg [255:0] key_buffer;
    reg [7:0] rcon;

    wire [31:0] prev_word;
    wire [31:0] old_word;
    wire [31:0] rot_prev_word;

    assign prev_word = key_buffer[31:0];
    assign old_word  = key_buffer[255:224];
    assign rot_prev_word = {prev_word[23:0], prev_word[31:24]};

    wire is_complex_step = (round_num != 0) && (round_num[0] == 1'b1);

    wire [31:0] sbox_in;
    assign sbox_in = (is_complex_step) ? rot_prev_word : prev_word;

    wire [31:0] sbox_out;
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : sbox_loop
            sbox sbox_inst (
                .a(sbox_in[8*i +: 8]), 
                .c(sbox_out[8*i +: 8])
            );
        end
    endgenerate

    always @(*) begin
        case (round_num >> 1)
            4'd0: rcon = 8'h01;
            4'd1: rcon = 8'h02;
            4'd2: rcon = 8'h04;
            4'd3: rcon = 8'h08;
            4'd4: rcon = 8'h10;
            4'd5: rcon = 8'h20;
            4'd6: rcon = 8'h40;
            default: rcon = 8'h00;
        endcase
    end

    wire [31:0] temp_modifier;
    assign temp_modifier = sbox_out ^ (is_complex_step ? {rcon, 24'b0} : 32'b0);

    wire [31:0] next_w0, next_w1, next_w2, next_w3;
    
    assign next_w0 = old_word ^ temp_modifier;
    assign next_w1 = key_buffer[223:192] ^ next_w0;
    assign next_w2 = key_buffer[191:160] ^ next_w1;
    assign next_w3 = key_buffer[159:128]  ^ next_w2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            key_buffer <= 256'b0;
        end
        else if (round_num == 0 && enable_round) begin
            key_buffer <= key_in;
        end
        else if (enable_round) begin
            key_buffer <= {key_buffer[127:0], next_w0, next_w1, next_w2, next_w3};
        end
    end

    assign round_key_out = (round_num == 0) ? key_in[255:128] : key_buffer[127:0];

endmodule
