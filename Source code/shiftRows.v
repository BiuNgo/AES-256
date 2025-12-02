`timescale 1ns / 1ps

module shiftRows(
    input wire [127:0] in,
    output wire [127:0] shifted
);

    wire [7:0] r0c0 = in[127:120];
    wire [7:0] r1c0 = in[119:112];
    wire [7:0] r2c0 = in[111:104];
    wire [7:0] r3c0 = in[103:96];

    wire [7:0] r0c1 = in[95:88];
    wire [7:0] r1c1 = in[87:80];
    wire [7:0] r2c1 = in[79:72];
    wire [7:0] r3c1 = in[71:64];

    wire [7:0] r0c2 = in[63:56];
    wire [7:0] r1c2 = in[55:48];
    wire [7:0] r2c2 = in[47:40];
    wire [7:0] r3c2 = in[39:32];

    wire [7:0] r0c3 = in[31:24];
    wire [7:0] r1c3 = in[23:16];
    wire [7:0] r2c3 = in[15:8];
    wire [7:0] r3c3 = in[7:0];

    assign shifted[127:120] = r0c0;
    assign shifted[119:112] = r1c1;
    assign shifted[111:104] = r2c2;
    assign shifted[103:96]  = r3c3;

    assign shifted[95:88] = r0c1;
    assign shifted[87:80] = r1c2;
    assign shifted[79:72] = r2c3;
    assign shifted[71:64] = r3c0;

    assign shifted[63:56] = r0c2;
    assign shifted[55:48] = r1c3;
    assign shifted[47:40] = r2c0;
    assign shifted[39:32] = r3c1;

    assign shifted[31:24] = r0c3;
    assign shifted[23:16] = r1c0;
    assign shifted[15:8]  = r2c1;
    assign shifted[7:0]   = r3c2;

endmodule