`timescale 1ns / 1ps

module AES_tb();

    reg clk;
    reg reset;
    reg start;
    reg [127:0] plaintext;
    reg [255:0] key;
    wire [127:0] ciphertext;
    wire done;

    integer file_handle;
    integer scan_result;
    integer count_val;
    reg [255:0] file_key;
    reg [127:0] file_plaintext;
    reg [127:0] file_expected_ciphertext;
    
    reg [8*20:1] label_dummy; 
    reg [8*1:1]  equal_dummy;

    integer tests_passed;
    integer tests_failed;

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
        tests_passed = 0;
        tests_failed = 0;

        file_handle = $fopen("input.txt", "r");

        #1;
        reset = 0;
        #1;

        while (!$feof(file_handle)) begin
            scan_result = $fscanf(file_handle, "%s %s %d", label_dummy, equal_dummy, count_val);
            
            if (scan_result == 3) begin
                
                scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_key);
                
                scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_plaintext);
                
                scan_result = $fscanf(file_handle, "%s %s %h", label_dummy, equal_dummy, file_expected_ciphertext);

                key = file_key;
                plaintext = file_plaintext;

                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;

                wait(done == 1);
                
                if (ciphertext === file_expected_ciphertext) begin
                    $display("Test %0d: PASSED", count_val);
                    tests_passed = tests_passed + 1;
                end else begin
                    $display("Test %0d: FAILED", count_val);
                    $display("   Key:      %h", key);
                    $display("   PT:       %h", plaintext);
                    $display("   Exp CT:   %h", file_expected_ciphertext);
                    $display("   Got CT:   %h", ciphertext);
                    tests_failed = tests_failed + 1;
                end

                #1;
            end
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
