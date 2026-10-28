//*****************************************************//
//    COMPONENT : AHB_DEFINES                          //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_defines.sv                       //
//*****************************************************//

`define ADDR_WIDTH 32
`define DATA_WIDTH 32

// HWRITE enum
typedef enum bit {AHB_READ  = 1'b0,
                  AHB_WRITE = 1'b1
                  } hwrite_e;
// HTRANS enum
typedef enum bit [1 : 0] {IDLE   = 2'b00, 
                          BUSY   = 2'b01, 
                          NONSEQ = 2'b10, 
                          SEQ    = 2'b11
                         } htrans_e;
// HBURST enum
typedef enum bit [2 : 0] {SINGLE = 3'b000,
                          INCR   = 3'b001, 
                          WRAP4  = 3'b010, 
                          INCR4  = 3'b011, 
                          WRAP8  = 3'b100, 
                          INCR8  = 3'b101, 
                          WRAP16 = 3'b110, 
                          INCR16 = 3'b111
                         } hburst_e;
// HSIZE enum
typedef enum bit [2 : 0] {BYTE        = 3'b000,
                          HALFWORD    = 3'b001,
                          WORD        = 3'b010,
                          DOUBLEWORD  = 3'b011,
                          WORD_LINE_4 = 3'b100,
                          WORD_LINE_8 = 3'b101,
                          WORD_512    = 3'b110,
                          WORD_1024   = 3'b111
                          } hsize_e;

// HRESP enum
typedef enum bit {OKAY  = 1'b0,
                  ERROR = 1'b1
                  } hresp_e;