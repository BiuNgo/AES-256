#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xparameters.h"
#include "sleep.h"

// Define Device IDs (Check xparameters.h for your specific IDs)
#define GPIO_DATA_ID 0
#define GPIO_CTRL_ID 1
#define GPIO_READ_ID 2
#define GPIO_OUT_ID  3

XGpio Gpio_Data, Gpio_Ctrl, Gpio_ReadCfg, Gpio_Out;

// Helper to convert hex char to int
u8 hex2int(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return 0;
}

// Function to write a 32-bit chunk to the wrapper
void write_chunk(u8 addr, u32 data) {
    XGpio_DiscreteWrite(&Gpio_Data, 1, data);       // Set Data
    XGpio_DiscreteWrite(&Gpio_Data, 2, addr);       // Set Address
    XGpio_DiscreteWrite(&Gpio_Ctrl, 1, 1);          // Write Enable HIGH
    XGpio_DiscreteWrite(&Gpio_Ctrl, 1, 0);          // Write Enable LOW
}

int main() {
    init_platform();
    
    // Initialize GPIOs
    XGpio_Initialize(&Gpio_Data, GPIO_DATA_ID);
    XGpio_Initialize(&Gpio_Ctrl, GPIO_CTRL_ID);
    XGpio_Initialize(&Gpio_ReadCfg, GPIO_READ_ID);
    XGpio_Initialize(&Gpio_Out, GPIO_OUT_ID);

    // Set directions (0=Output to FPGA, 1=Input from FPGA)
    XGpio_SetDataDirection(&Gpio_Data, 1, 0x00000000); 
    XGpio_SetDataDirection(&Gpio_Data, 2, 0x00000000); 
    XGpio_SetDataDirection(&Gpio_Ctrl, 1, 0x00000000); 
    XGpio_SetDataDirection(&Gpio_Ctrl, 2, 0x00000000);
    XGpio_SetDataDirection(&Gpio_ReadCfg, 1, 0x00000000);
    XGpio_SetDataDirection(&Gpio_ReadCfg, 2, 0x00000000);
    XGpio_SetDataDirection(&Gpio_Out, 1, 0xFFFFFFFF); // Ciphertext is Input
    XGpio_SetDataDirection(&Gpio_Out, 2, 0xFFFFFFFF); // Done flag is Input

    char key_str[65];
    char plain_str[33];
    u32 key_chunks[8];
    u32 plain_chunks[4];
    u32 cipher_chunks[4];

    while(1) {
        print("\r\n=== AES-256 FPGA Accelerator ===\r\n");
        
        // 1. Reset
        XGpio_DiscreteWrite(&Gpio_ReadCfg, 2, 1);
        usleep(10);
        XGpio_DiscreteWrite(&Gpio_ReadCfg, 2, 0);

        // 2. Get Input via UART (PuTTY)
        print("Enter 64-char Hex Key: ");
        for(int i=0; i<64; i++) key_str[i] = inbyte();
        print("\r\nKey Received.\r\n");

        print("Enter 32-char Hex Plaintext: ");
        for(int i=0; i<32; i++) plain_str[i] = inbyte();
        print("\r\nPlaintext Received. Processing...\r\n");

        // 3. Parse Strings to chunks
        // (Note: This is simplified parsing, assumes correct MSB/LSB ordering for your logic)
        // You may need to reverse loops depending on if your string is Big/Little Endian
        for(int k=0; k<8; k++) { 
             sscanf(&key_str[k*8], "%8x", &key_chunks[7-k]); // Fill logical chunks
             write_chunk(k, key_chunks[7-k]); // Write to hardware
        }
        for(int p=0; p<4; p++) {
             sscanf(&plain_str[p*8], "%8x", &plain_chunks[3-p]);
             write_chunk(8+p, plain_chunks[3-p]);
        }

        // 4. Start Encryption
        XGpio_DiscreteWrite(&Gpio_Ctrl, 2, 1); // Start High
        XGpio_DiscreteWrite(&Gpio_Ctrl, 2, 0); // Start Low

        // 5. Poll Done
        while(XGpio_DiscreteRead(&Gpio_Out, 2) == 0);

        // 6. Read Result
        print("Ciphertext: ");
        for(int i=3; i>=0; i--) {
            XGpio_DiscreteWrite(&Gpio_ReadCfg, 1, i); // Set Read Addr
            cipher_chunks[i] = XGpio_DiscreteRead(&Gpio_Out, 1);
            xil_printf("%08x", cipher_chunks[i]);
        }
        print("\r\n");
    }

    cleanup_platform();
    return 0;
}