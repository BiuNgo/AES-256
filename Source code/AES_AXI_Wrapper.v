module AES_AXI_Wrapper(
    input wire clk,
    input wire reset,
    // Interface to Processor (via AXI GPIO)
    input wire [31:0] data_in,      // 32-bit chunks of data from CPU
    input wire [3:0]  write_addr,   // Address to select which chunk to write
    input wire        write_en,     // Write enable signal
    input wire        start_cmd,    // Start signal from CPU
    output wire       done_flag,    // Done signal to CPU
    output reg [31:0] data_out,     // 32-bit chunks of result to CPU
    input wire [1:0]  read_addr     // Address to select which result chunk to read
    );

    // Internal Registers
    reg [255:0] key_reg;
    reg [127:0] plain_reg;
    wire [127:0] cipher_wire;
    wire aes_done;

    // Instantiate your original AES module
    AES aes_inst (
        .clk(clk),
        .reset(reset),
        .start(start_cmd),
        .plaintext(plain_reg),
        .key(key_reg),
        .ciphertext(cipher_wire),
        .done(aes_done)
    );

    assign done_flag = aes_done;

    // Write Logic (CPU -> FPGA)
    // We split 256-bit Key into 8x 32-bit chunks
    // We split 128-bit Plaintext into 4x 32-bit chunks
    always @(posedge clk) begin
        if (reset) begin
            key_reg <= 0;
            plain_reg <= 0;
        end else if (write_en) begin
            case (write_addr)
                // Writing Key (0-7)
                4'd0: key_reg[255:224] <= data_in;
                4'd1: key_reg[223:192] <= data_in;
                4'd2: key_reg[191:160] <= data_in;
                4'd3: key_reg[159:128] <= data_in;
                4'd4: key_reg[127:96]  <= data_in;
                4'd5: key_reg[95:64]   <= data_in;
                4'd6: key_reg[63:32]   <= data_in;
                4'd7: key_reg[31:0]    <= data_in;
                // Writing Plaintext (8-11)
                4'd8: plain_reg[127:96] <= data_in;
                4'd9: plain_reg[95:64]  <= data_in;
                4'd10: plain_reg[63:32] <= data_in;
                4'd11: plain_reg[31:0]  <= data_in;
            endcase
        end
    end

    // Read Logic (FPGA -> CPU)
    // Read Ciphertext in 4 chunks
    always @(*) begin
        case (read_addr)
            2'd0: data_out = cipher_wire[127:96];
            2'd1: data_out = cipher_wire[95:64];
            2'd2: data_out = cipher_wire[63:32];
            2'd3: data_out = cipher_wire[31:0];
            default: data_out = 32'b0;
        endcase
    end

endmodule