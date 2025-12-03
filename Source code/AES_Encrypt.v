`timescale 1ns / 1ps

module AES_Encrypt(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [127:0] in,
    input wire [255:0] key,
    output reg [127:0] out,
    output reg done
);

    localparam [2:0] S_IDLE         = 3'b000,
                     S_INIT_ADD_KEY = 3'b001,
                     S_ROUNDS       = 3'b010,
                     S_FINAL_ROUND  = 3'b011,
                     S_DONE         = 3'b100;

    reg [2:0] state_reg, next_state;
    reg [3:0] round_counter_reg, next_round_counter;
    reg [127:0] state_data_reg, next_state_data;

    wire [127:0] round_key;
    wire key_gen_enable;

    assign key_gen_enable = (state_reg != S_IDLE) && (state_reg != S_DONE);

    keyExpansion ke_inst (
        .clk(clk),
        .reset(reset),
        .enable_round(key_gen_enable),
        .key_in(key),
        .round_num(round_counter_reg),
        .round_key_out(round_key)
    );

    wire [127:0] sb_out;
    wire [127:0] sr_out;
    wire [127:0] mc_out;
    wire [127:0] ark_in;
    wire [127:0] round_result;

    subBytes sb_inst (
        .in(state_data_reg), 
        .out(sb_out)
    );

    shiftRows sr_inst (
        .in(sb_out), 
        .shifted(sr_out)
    );

    mixColumns mc_inst (
        .state_in(sr_out), 
        .state_out(mc_out)
    );

    assign ark_in = (state_reg == S_FINAL_ROUND) ? sr_out : mc_out;

    assign round_result = ark_in ^ round_key;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg           <= S_IDLE;
            round_counter_reg   <= 0;
            state_data_reg      <= 128'b0;
            out                 <= 128'b0;
            done                <= 1'b0;
        end else begin
            state_reg           <= next_state;
            round_counter_reg   <= next_round_counter;
            state_data_reg      <= next_state_data;
            
            if (reset) begin
                done <= 1'b0;
            end else if (state_reg == S_DONE) begin
                out <= next_state_data;
                done <= 1'b1;
            end else if (start) begin
                done <= 1'b0;
            end
        end
    end

    always @(*) begin
        next_state = state_reg;
        next_round_counter = round_counter_reg;
        next_state_data = state_data_reg;

        case (state_reg)
            S_IDLE: begin
                if (start) begin
                    next_state = S_INIT_ADD_KEY;
                    next_round_counter = 0; 
                end
            end

            S_INIT_ADD_KEY: begin
                next_state_data = in ^ round_key;
                
                next_round_counter = 1;
                next_state = S_ROUNDS;
            end

            S_ROUNDS: begin
                next_state_data = round_result;

                if (round_counter_reg < 13) begin
                    next_round_counter = round_counter_reg + 1;
                    next_state = S_ROUNDS;
                end else begin
                    next_round_counter = 14; 
                    next_state = S_FINAL_ROUND;
                end
            end

            S_FINAL_ROUND: begin
                next_state_data = round_result;
                next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule
