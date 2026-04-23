
package UC_regfile_package;
localparam DVSEC_DEPTH       = 'h48;
localparam DATA_WIDTH        = 'd32;
localparam MEM_BLOCK_DEPTH   = 'd1024;

localparam [$clog2(DVSEC_DEPTH) - 1 : 0] PCIE_EX_WORD_OFFSET               = 'h0  / 'd4;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] LINK_CAPABILITY_WORD_OFFSET       = 'hC  / 'd4;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] LINK_CONTROL_WORD_OFFSET          = 'h10 / 'd4;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] LINK_STATUS_WORD_OFFSET           = 'h14 / 'd4;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] LINK_NOTIFICATION_WORD_OFFSET     = 'h18 / 'd4;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] ERROR_AND_TESTING_WORD_OFFSET     = 'h30;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] MAILBOX_INDEX_LOW_WORD_OFFSET     = 'd24;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] MAILBOX_INDEX_HIGH_WORD_OFFSET    = MAILBOX_INDEX_LOW_WORD_OFFSET + 1;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] MAILBOX_DATA_LOW_WORD_OFFSET      = MAILBOX_INDEX_LOW_WORD_OFFSET + 2;
localparam [$clog2(DVSEC_DEPTH) - 1 : 0] MAILBOX_DATA_HIGH_WORD_OFFSET     = MAILBOX_INDEX_LOW_WORD_OFFSET + 3;

localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] VENDOR_ID_WORD_OFFSET                    = 'd0;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] VENDOR_REGISTER_WORD_OFFSET              = 'd2;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET   = 'h10 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] UNCORRECTABLE_ERROR_MASK_WORD_OFFSET     = 'h14 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET = 'h18 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] CORRECTABLE_ERROR_STATUS_WORD_OFFSET     = 'h1C / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] CORRECTABLE_ERROR_MASK_WORD_OFFSET       = 'h20 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] HEADER_LOG1_WORD_OFFSET                  = 'h24 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] HEADER_LOG2_WORD_OFFSET                  = 'h2C / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] ADV_CAP_WORD_OFFSET                      = 'h54 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] FIN_CAP_WORD_OFFSET                      = 'h5C / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] ADV_CAP_CXL_WORD_OFFSET                  = 'h64 / 'd4;
localparam [$clog2(MEM_BLOCK_DEPTH) - 1 : 0] FIN_CAP_CXL_WORD_OFFSET                  = 'h6C / 'd4;

function automatic void calc_config_lanes(
    input  int          byte_idx,
    input  logic [11:0] base_addr,
    output logic [11:0] word_lane,
    output logic [4:0]  byte_lane
);
    logic [11:0] word_lane_temp;
    logic [1:0] byte_lane_temp;
    word_lane_temp = base_addr      + byte_idx;
    byte_lane_temp = base_addr[1:0] + byte_idx;
    word_lane      = word_lane_temp >> 2;
    byte_lane      = byte_lane_temp << 3;
endfunction

function automatic void calc_mem_lanes(
    input  int          byte_idx,
    input  logic [19:0] base_addr,
    output logic [19:0] word_lane,
    output logic [4:0]  byte_lane
);
    logic [19:0] word_lane_temp;
    logic [1:0] byte_lane_temp;
    word_lane_temp = base_addr + byte_idx;
    byte_lane_temp = base_addr[1:0] + byte_idx;
    word_lane      = word_lane_temp >> 2;
    byte_lane      = byte_lane_temp << 3;
endfunction
endpackage
