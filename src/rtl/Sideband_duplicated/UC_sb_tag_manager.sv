/*
Authour: Shahd Mohamed , Ashraf sherif 

Module_name: UC_sb_tag_manager

Description: TX Path: Validates the incoming tag and ensures it is unique. If the tag is invalid or already used,
a new valid tag is generated through remapping.

RX Path: Checks the received completion tag against the stored records. If the tag was remapped earlier, 
the original tag is restored; otherwise, an invalid or unknown tag is flagged as an error.
*/
module UC_sb_tag_manager (
    //-------------------------------- Inputs --------------------------//
    input logic        i_clk,
    input logic        i_rst_n,
    input logic        i_valid,           //Indicates that the incoming tag is ready to be validated and stored 
    input logic [4:0]  i_tag_store,      //The tag value to be stored 
    input logic        i_check,         //Triggers validation for a received tag to start check it
    input logic [4:0]  i_current_tag,  //Tag received from completion controller to be checked
    input logic        i_init_n,           // init signal for software

    //-------------------------------- Outputs --------------------------------------//
    output logic        o_correct,           // Set to 1 if the tag is valid and accepted.
    output logic [4:0]  o_new_tag,           // Outputs a new tag if the original one was invalid or reused
    output logic        o_uncorrect_tag,     // Set to 1 if the tag is not recognized or has an error 
    output logic [4:0]  o_old_tag         //Outputs the original tag if the received one was previously remapped 
 
);
    //------------------------ Parameters / localparams----------------------------//

    localparam logic [4:0] RESERVED_TAG = 5'b11111; // reserved for remote request

    //---------------------- Internal tracking tables-----------------------------//

    logic [31:0] used_tags;             // used_tags[tag] = 1 , this tag is currently allocated/outstanding

    logic [31:0] remap_valid;          // remap_valid[new_tag] = 1 , this allocated tag was created by remap

    logic [4:0]  orig_tag_map [31:0]; // orig_tag_map[new_tag] = original requested tag before remap

    integer i;

     //------------------------ Find first free tag helper------------------------//
    
    function automatic logic find_free_tag(
        input  logic [31:0] used_in,
        output logic [4:0]  free_tag
    );
        logic found;
        integer k;
        begin
            found    = 1'b0;
            free_tag = 5'd0;

            for (k = 0; k < 31; k++) begin
                if (!used_in[k] && !found) begin
                    free_tag = k[4:0];
                    found    = 1'b1;
                end
            end

            find_free_tag = found;
        end
    endfunction
   //---------------------------- Sequential logic----------------------------//
  
    always_ff @(posedge i_clk or negedge i_rst_n) begin : TAG_MANAGER_SEQ
        logic [31:0] used_n;
        logic [31:0] remap_n;
        logic [4:0]  free_tag_tmp;
        logic        free_found;

        if (!i_rst_n) begin
            used_tags      <= '0;
            remap_valid    <= '0;
            o_correct        <= 1'b0;
            o_new_tag        <= 5'd0;
            o_uncorrect_tag  <= 1'b0;
            o_old_tag        <= 5'd0;

            for (i = 0; i < 32; i++) begin
                orig_tag_map[i] <= 5'd0;
            end
        end
        else if (!i_init_n) begin
            used_tags      <= '0;
            remap_valid    <= '0;
            o_correct        <= 1'b0;
            o_new_tag        <= 5'd0;
            o_uncorrect_tag  <= 1'b0;
            o_old_tag        <= 5'd0;

            for (i = 0; i < 32; i++) begin
                orig_tag_map[i] <= 5'd0;
            end
        end
        else begin
        
            o_correct       <= 1'b0;
            o_new_tag       <= 5'd0;
            o_uncorrect_tag <= 1'b0;
            o_old_tag       <= 5'd0;

            // temp copies so we can support check + valid in same cycle
            used_n  = used_tags;
            remap_n = remap_valid;

           // 1) RX path: completion tag check / release
            
            if (i_check) begin
                if (used_n[i_current_tag]) begin
                    // recognized tag
                    o_uncorrect_tag <= 1'b0;

                    if (remap_n[i_current_tag]) begin
                        o_old_tag <= orig_tag_map[i_current_tag];
                    end
                    else begin
                        o_old_tag <= i_current_tag;
                    end

                    // release tag after successful completion match
                    used_n[i_current_tag]  = 1'b0;
                    remap_n[i_current_tag] = 1'b0;
                end
                else begin
                    // unknown / already released / invalid completion tag
                    o_uncorrect_tag <= 1'b1;
                    o_old_tag       <= 5'd0;
                end
            end

           // 2) TX path: validate / allocate / remap

            if (i_valid) begin
                // Case A: requested tag is valid and free and not reserved

                if ((i_tag_store != RESERVED_TAG) && !used_n[i_tag_store]) begin
                    o_correct          <= 1'b1;
                    o_new_tag          <= i_tag_store;
                    used_n[i_tag_store] = 1'b1;

                    // no remap on this tag
                    remap_n[i_tag_store] = 1'b0;
                end
                else begin
                    // Case B: invalid/reused/conflicting -> remap
                    free_found = find_free_tag(used_n, free_tag_tmp);

                    if (free_found) begin
                        o_correct             <= 1'b0;
                        o_new_tag             <= free_tag_tmp;
                        used_n[free_tag_tmp] = 1'b1;
                        remap_n[free_tag_tmp] = 1'b1;
                        orig_tag_map[free_tag_tmp] <= i_tag_store;
                    end
                    else begin
                        // No free tags available
                        o_correct <= 1'b0;
                        o_new_tag <= 5'd0;
                    end
                end
            end

            // commit next state
            used_tags   <= used_n;
            remap_valid <= remap_n;
        end
    end

endmodule