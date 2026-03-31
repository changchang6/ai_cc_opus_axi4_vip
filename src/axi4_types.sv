//-----------------------------------------------------------------------------
// File: axi4_types.sv
// Description: AXI4 type definitions and enumerations
//-----------------------------------------------------------------------------

package axi4_types_pkg;

    // AXI4 Burst Type Encoding
    typedef enum logic [1:0] {
        BURST_FIXED = 2'b00,
        BURST_INCR  = 2'b01,
        BURST_WRAP  = 2'b10,
        BURST_RSVD  = 2'b11
    } axi4_burst_e;

    // AXI4 Response Type Encoding
    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } axi4_resp_e;

    // AXI4 Transaction Type
    typedef enum bit {
        TRANS_READ  = 1'b0,
        TRANS_WRITE = 1'b1
    } axi4_trans_type_e;

    // AXI4 Lock Type
    typedef enum logic [1:0] {
        LOCK_NORMAL    = 2'b00,
        LOCK_EXCLUSIVE = 2'b01,
        LOCK_LOCKED    = 2'b10,
        LOCK_RSVD     = 2'b11
    } axi4_lock_e;

    // AXI4 Cache Attributes
    typedef enum logic [3:0] {
        CACHE_NC_NC       = 4'b0000,  // Non-cacheable, Non-bufferable
        CACHE_NC_B        = 4'b0001,  // Non-cacheable, Bufferable
        CACHE_WT_RA       = 4'b0010,  // Write-through, Read-allocate
        CACHE_WT_RWA      = 4'b0011,  // Write-through, Read/Write-allocate
        CACHE_WB_RA       = 4'b0110,  // Write-back, Read-allocate
        CACHE_WB_RWA      = 4'b0111   // Write-back, Read/Write-allocate
    } axi4_cache_e;

    // AXI4 Protection Type
    typedef enum logic [2:0] {
        PROT_NORMAL      = 3'b000,
        PROT_PRIVILEGED  = 3'b001,
        PROT_NONSECURE   = 3'b010,
        PROT_INSTRUCTION = 3'b100
    } axi4_prot_e;

    // AXI4 Address Channel Structure (Write Address)
    typedef struct {
        logic        valid;
        logic        ready;
        logic [31:0] addr;
        logic [7:0]  id;
        logic [7:0]  len;
        logic [2:0]  size;
        logic [1:0]  burst;
        logic        lock;
        logic [3:0]  cache;
        logic [2:0]  prot;
        logic [3:0]  qos;
        logic [3:0]  region;
    } axi4_aw_channel_t;

    // AXI4 Address Channel Structure (Read Address)
    typedef struct {
        logic        valid;
        logic        ready;
        logic [31:0] addr;
        logic [7:0]  id;
        logic [7:0]  len;
        logic [2:0]  size;
        logic [1:0]  burst;
        logic        lock;
        logic [3:0]  cache;
        logic [2:0]  prot;
        logic [3:0]  qos;
        logic [3:0]  region;
    } axi4_ar_channel_t;

    // AXI4 Write Data Channel Structure
    typedef struct {
        logic         valid;
        logic         ready;
        logic [127:0] data;
        logic [15:0]  strb;
        logic         last;
    } axi4_w_channel_t;

    // AXI4 Read Data Channel Structure
    typedef struct {
        logic         valid;
        logic         ready;
        logic [127:0] data;
        logic [7:0]   id;
        logic [1:0]   resp;
        logic         last;
    } axi4_r_channel_t;

    // AXI4 Write Response Channel Structure
    typedef struct {
        logic        valid;
        logic        ready;
        logic [7:0]  id;
        logic [1:0]  resp;
    } axi4_b_channel_t;

    // Maximum burst length constants
    localparam int MAX_BURST_LEN_INCR   = 255;  // 256 beats
    localparam int MAX_BURST_LEN_FIXED   = 15;   // 16 beats
    localparam int MAX_BURST_LEN_SPLIT   = 31;   // 32 beats for split burst
    localparam int ADDR_BOUNDARY_4KB     = 4096;
    localparam int ADDR_BOUNDARY_1KB     = 1024;
    localparam int ADDR_BOUNDARY_2KB     = 2048;

    // Function to calculate next address for WRAP burst
    function automatic logic [31:0] calc_wrap_addr(
        logic [31:0] addr,
        logic [7:0]  len,
        logic [2:0]  size,
        int          beat_idx
    );
        int beat_size;
        int wrap_boundary;
        logic [31:0] next_addr;

        beat_size = 1 << size;
        wrap_boundary = ((addr / ((len + 1) * beat_size)) * ((len + 1) * beat_size));
        next_addr = wrap_boundary + ((addr - wrap_boundary + beat_idx * beat_size) % ((len + 1) * beat_size));
        return next_addr;
    endfunction

    // Function to check if address crosses 2KB boundary
    function automatic bit crosses_2kb_boundary(
        logic [31:0] start_addr,
        logic [7:0]  len,
        logic [2:0]  size
    );
        logic [31:0] end_addr;
        logic [31:0] start_boundary;
        logic [31:0] end_boundary;

        end_addr = start_addr + ((len + 1) * (1 << size)) - 1;
        start_boundary = (start_addr / ADDR_BOUNDARY_2KB) * ADDR_BOUNDARY_2KB;
        end_boundary   = (end_addr   / ADDR_BOUNDARY_2KB) * ADDR_BOUNDARY_2KB;

        return (start_boundary != end_boundary);
    endfunction

endpackage : axi4_types_pkg