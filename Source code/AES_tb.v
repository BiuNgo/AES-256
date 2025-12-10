`timescale 1ns / 1ps

module AES_tb();

    reg clk;
    reg reset;
    reg [31:0] data_in;
    reg [3:0]  write_addr;
    reg        write_en;
    reg        start_cmd;
    reg [1:0]  read_addr;

    wire        done_flag;
    wire [31:0] data_out;

    integer file_handle;
    integer scan_result;
    integer count_val;
    
    reg [255:0] file_key;
    reg [127:0] file_plaintext;
    reg [127:0] file_expected_ciphertext;
    
    reg [127:0] reconstructed_ciphertext; 

    reg [8*20:1] label_dummy; 
    reg [8*1:1]  equal_dummy;

    integer tests_passed;
    integer tests_failed;
    integer i;

    AES_Driver dut (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .write_addr(write_addr),
        .write_en(write_en),
        .start_cmd(start_cmd),
        .done_flag(done_flag),
        .data_out(data_out),
        .read_addr(read_addr)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        start_cmd = 0;
        data_in = 0;
        write_addr = 0;
        write_en = 0;
        read_addr = 0;
        tests_passed = 0;
        tests_failed = 0;

        file_handle = $fopen("input.txt", "r");
        if (file_handle == 0) begin
            $display("Error: Could not open input.txt");
            $finish;
        end

        #10;
        reset = 0;
        #10;

        while (!$feof(file_handle)) begin
            scan_result = $fscanf(file_handle, "%s %s %d", label_dummy, equal_dummy, count_val);
                
            scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_key);
            scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_plaintext);
            scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_expected_ciphertext);

            @(posedge clk);
            write_en = 1;
            for (i = 0; i < 8; i = i + 1) begin
                write_addr = i;
                data_in = file_key[255 - (i*32) -: 32]; 
                @(posedge clk);
            end

            for (i = 0; i < 4; i = i + 1) begin
                write_addr = 8 + i;
                data_in = file_plaintext[127 - (i*32) -: 32];
                @(posedge clk);
            end
                
            write_en = 0;

            start_cmd = 1;
            @(posedge clk);
            start_cmd = 0;

            wait(done_flag == 1);
                
            @(posedge clk);
            for (i = 0; i < 4; i = i + 1) begin
                read_addr = i;
                #1;
                reconstructed_ciphertext[127 - (i*32) -: 32] = data_out;
            end

            if (reconstructed_ciphertext === file_expected_ciphertext) begin
                $display("Test %0d: PASSED", count_val);
                tests_passed = tests_passed + 1;
            end else begin
                $display("Test %0d: FAILED", count_val);
                $display("   Key:      %h", file_key);
                $display("   PT:       %h", file_plaintext);
                $display("   Exp CT:   %h", file_expected_ciphertext);
                $display("   Got CT:   %h", reconstructed_ciphertext);
                tests_failed = tests_failed + 1;
            end

            #10;
        end

        $fclose(file_handle);
        
        $display("-----------------------------------------");
        $display("SUMMARY:");
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);
        $display("-----------------------------------------");
        
        $finish;
    end

endmodule
