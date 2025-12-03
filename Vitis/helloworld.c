#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xparameters.h"
#include "sleep.h"

// **************************************************************************
// MANUAL TIMER SETUP (Bypassing xtime_l.h)
// **************************************************************************
// Zynq-7000 Global Timer Base Address
#define GLOBAL_TMR_BASE 0xF8F00200
#define GTIMER_COUNTER_LOWER (*(volatile u32*)(GLOBAL_TMR_BASE + 0x00))
#define GTIMER_COUNTER_UPPER (*(volatile u32*)(GLOBAL_TMR_BASE + 0x04))
#define GTIMER_CONTROL       (*(volatile u32*)(GLOBAL_TMR_BASE + 0x08))

// Global Timer runs at 1/2 of CPU Frequency
// Check XPAR_CPU_CORE_CLOCK_FREQ_HZ in xparameters.h (usually 650MHz for Zynq -1 speed grade)
// If undefined, we assume 650MHz (Arty Z7 standard) -> Timer = 325MHz
#ifndef XPAR_CPU_CORE_CLOCK_FREQ_HZ
#define XPAR_CPU_CORE_CLOCK_FREQ_HZ 650000000
#endif
#define COUNTS_PER_SECOND (XPAR_CPU_CORE_CLOCK_FREQ_HZ / 2)

void StartTimer() {
    // Enable the Global Timer (Bit 0 = 1)
    GTIMER_CONTROL = 0x1; 
}

u64 GetTime() {
    u32 low, high, high2;
    // Read high/low registers safely (handle rollover)
    do {
        high = GTIMER_COUNTER_UPPER;
        low  = GTIMER_COUNTER_LOWER;
        high2 = GTIMER_COUNTER_UPPER;
    } while (high != high2); // Retry if high word changed during read
    
    return ((u64)high << 32) | low;
}

// **************************************************************************
// GPIO CONFIGURATION
// **************************************************************************
XGpio Gpio_Data;    // ID 0
XGpio Gpio_Ctrl;    // ID 1
XGpio Gpio_ReadCfg; // ID 2
XGpio Gpio_Out;     // ID 3

int ConfigGpio(XGpio *InstancePtr, u32 BaseAddr) {
    XGpio_Config cfg;
    cfg.BaseAddress = BaseAddr;
    cfg.InterruptPresent = 0;
    cfg.IsDual = 1;
    return XGpio_CfgInitialize(InstancePtr, &cfg, BaseAddr);
}

void write_chunk(u8 addr, u32 data) {
    XGpio_DiscreteWrite(&Gpio_Data, 1, data);
    XGpio_DiscreteWrite(&Gpio_Data, 2, addr);
    XGpio_DiscreteWrite(&Gpio_Ctrl, 1, 1);
    XGpio_DiscreteWrite(&Gpio_Ctrl, 1, 0);
}

int main() {
    init_platform();
    
    // Enable the Hardware Timer manually
    StartTimer();
    u64 tStart, tEnd;
    
    // Initialize GPIOs
    ConfigGpio(&Gpio_Data, XPAR_AXI_GPIO_0_BASEADDR);
    ConfigGpio(&Gpio_Ctrl, XPAR_AXI_GPIO_1_BASEADDR);
    ConfigGpio(&Gpio_ReadCfg, XPAR_AXI_GPIO_2_BASEADDR);
    ConfigGpio(&Gpio_Out, XPAR_AXI_GPIO_3_BASEADDR);

    // Set directions
    XGpio_SetDataDirection(&Gpio_Data, 1, 0x0);     
    XGpio_SetDataDirection(&Gpio_Data, 2, 0x0);     
    XGpio_SetDataDirection(&Gpio_Ctrl, 1, 0x0);     
    XGpio_SetDataDirection(&Gpio_Ctrl, 2, 0x0);     
    XGpio_SetDataDirection(&Gpio_ReadCfg, 1, 0x0);  
    XGpio_SetDataDirection(&Gpio_ReadCfg, 2, 0x0);  
    XGpio_SetDataDirection(&Gpio_Out, 1, 0xFFFFFFFF); 
    XGpio_SetDataDirection(&Gpio_Out, 2, 0xFFFFFFFF); 

    char key_str[65];
    char plain_str[33];
    u32 key_chunks[8];
    u32 plain_chunks[4];
    u32 cipher_chunks[4];

    while(1) {
        print("\r\n================================\r\n");
        print("    AES-256 FPGA Accelerator    \r\n");
        print("================================\r\n");
        
        // --- 1. RESET SEQUENCE ---
        XGpio_DiscreteWrite(&Gpio_ReadCfg, 2, 1); 
        usleep(100); 
        XGpio_DiscreteWrite(&Gpio_ReadCfg, 2, 0); 
        
        // --- 2. GET INPUT (WITH ECHO) ---
        print("Enter 64-char Hex Key: ");
        for(int i=0; i<64; i++) {
            key_str[i] = inbyte();
            outbyte(key_str[i]); // <--- Echo Input
        }
        key_str[64] = '\0';
        print("\r\n");

        print("Enter 32-char Hex Plaintext: ");
        for(int i=0; i<32; i++) {
            plain_str[i] = inbyte();
            outbyte(plain_str[i]); // <--- Echo Input
        }
        plain_str[32] = '\0';
        print("\r\n\r\nProcessing...\r\n");

        // --- 3. SEND DATA TO FPGA ---
        for(int k=0; k<8; k++) { 
             sscanf(&key_str[k*8], "%8lx", &key_chunks[7-k]); 
             write_chunk(k, key_chunks[7-k]); 
        }
        for(int p=0; p<4; p++) {
             sscanf(&plain_str[p*8], "%8lx", &plain_chunks[3-p]);
             write_chunk(8+p, plain_chunks[3-p]);
        }

        // --- 4. EXECUTE AND TIME ---
        
        // Capture Start Time (Manual Read)
        tStart = GetTime();

        // Pulse Start Signal
        XGpio_DiscreteWrite(&Gpio_Ctrl, 2, 1); 
        XGpio_DiscreteWrite(&Gpio_Ctrl, 2, 0); 

        // Poll Done Flag
        volatile int timeout = 0;
        volatile u32 done_bit = 0;
        
        while(done_bit == 0 && timeout < 1000000) {
            done_bit = XGpio_DiscreteRead(&Gpio_Out, 2);
            timeout++;
        }

        // Capture End Time (Manual Read)
        tEnd = GetTime();

        // --- 5. CALCULATE TIME ---
        u64 ticks = tEnd - tStart;
        // Calculate microseconds: (ticks * 1000000) / Frequency
        // We use integer math to avoid linker issues with floats
        u64 time_us = (ticks * 1000000) / COUNTS_PER_SECOND;

        // --- 6. DISPLAY RESULTS ---
        print("Ciphertext: ");
        for(int i=0; i<=3; i++) { 
            XGpio_DiscreteWrite(&Gpio_ReadCfg, 1, i); 
            for(volatile int d=0; d<20; d++); 
            cipher_chunks[i] = XGpio_DiscreteRead(&Gpio_Out, 1);
            xil_printf("%08x", cipher_chunks[i]);
        }
        print("\r\n");

        if(done_bit) {
            print("Status: Success\r\n");
            // xil_printf does not support %f, using %d (integer)
            xil_printf("Hardware Time: %d us\r\n", (int)time_us);
            xil_printf("Clock Cycles: %d\r\n", (int)ticks); 
        } else {
            print("Status: Timeout (Signal missed or core stuck)\r\n");
        }
    }

    cleanup_platform();
    return 0;
}
