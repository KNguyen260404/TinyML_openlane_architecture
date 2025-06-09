module Random_forest_top_ver2 #(
    parameter NODE_WIDTH = 120,
    parameter ADDR_WIDTH = 10,
    parameter ROM_DEPTH = 512,
    parameter TREE_COUNT = 21,  // Number of decision trees
    parameter PIPELINE_DEPTH = 10  // Pipeline depth (also maximum tree depth)
)(
    input wire clk,
    input wire rst_n,

    // Input features from CAN bus
    input wire [63:0] arbitration_id,
    input wire [63:0] timestamp,
    input wire [63:0] data_field,
    
    input wire feature_valid, // Asserted when a new frame arrives
    output wire ready_for_next, // Indicates ready to receive next frame

    // Output
    output reg prediction_valid,
    output reg prediction_out,  // 0: normal, 1: attack
    output reg [4:0] frame_id_out  // ID of the frame being predicted
);

// Buffered reset signal to fix max slew violations
wire rst_n_buf;
sky130_fd_sc_hd__clkbuf_16 rst_buf (.A(rst_n), .X(rst_n_buf));

// Loop counters declared at module level
integer j;

// Count of frames currently in the pipeline
// reg [4:0] current_frame_count; // Unused - removing
reg [4:0] frame_id_in; // ID of incoming frame

// Use a streamlined voting approach
/* verilator lint_off UNUSEDSIGNAL */
reg [TREE_COUNT-1:0] tree_votes; // One-hot votes from trees - needed for reset
/* verilator lint_on UNUSEDSIGNAL */
reg [4:0] attack_votes; // Count of attack votes for current frame
reg [4:0] complete_votes; // Count of completed votes
reg [4:0] current_voting_frame; // Track which frame is voting

// Wires to connect instances of the pipelined tree
wire [TREE_COUNT-1:0] tree_predictions;
wire [TREE_COUNT-1:0] tree_prediction_valids;
wire [TREE_COUNT-1:0] tree_ready_for_next;
wire [4:0] tree_frame_id[0:TREE_COUNT-1]; // Frame ID being processed by each tree

// Signal ready for next frame when all trees are ready
assign ready_for_next = &tree_ready_for_next;

// Create 21 instances for each decision tree (with pipeline)
genvar i;
generate
    for (i = 0; i < TREE_COUNT; i = i + 1) begin : tree_instances
        pipelined_tree #(
            .NODE_WIDTH(NODE_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ROM_DEPTH(ROM_DEPTH),
            .TREE_INDEX(i),  // Tree index to load correct weight file
            .PIPELINE_STAGES(PIPELINE_DEPTH)
        ) u_tree (
            .clk(clk),
            .rst_n(rst_n_buf), // Use buffered reset
            .arbitration_id(arbitration_id),
            .timestamp(timestamp),
            .data_field(data_field),
            .feature_valid(feature_valid),
            .frame_id_in(frame_id_in),
            .ready_for_next(tree_ready_for_next[i]),
            .prediction_valid(tree_prediction_valids[i]),
            .prediction_out(tree_predictions[i]),
            .frame_id_out(tree_frame_id[i])
        );
    end
endgenerate

// Simplified FSM state definitions
localparam [1:0] IDLE = 2'b00;
localparam [1:0] COLLECTING = 2'b01;
localparam [1:0] VOTING = 2'b10;

reg [1:0] state;

// Main state machine and voting logic
always @(posedge clk or negedge rst_n_buf) begin // Use buffered reset
    if (!rst_n_buf) begin
        state <= IDLE;
        frame_id_in <= 0;
        // current_frame_count <= 0; // Unused - removing
        /* verilator lint_off UNUSEDSIGNAL */
        tree_votes <= 0;
        /* verilator lint_on UNUSEDSIGNAL */
        attack_votes <= 0;
        complete_votes <= 0;
        current_voting_frame <= 0;
        prediction_valid <= 0;
        prediction_out <= 0;
        frame_id_out <= 0;
    end else begin
        // Default state for prediction_valid (only high for one cycle)
        prediction_valid <= 0;
        
        case (state)
            IDLE: begin
                // Accept new frame if ready and frame is valid
                if (ready_for_next && feature_valid) begin
                    frame_id_in <= frame_id_in + 1;
                    state <= COLLECTING;
                end
                
                // Check for new prediction results
                for (j = 0; j < TREE_COUNT; j = j + 1) begin
                    if (tree_prediction_valids[j]) begin
                        if (tree_frame_id[j] == current_voting_frame) begin
                            tree_votes[j] <= tree_predictions[j];
                            if (tree_predictions[j]) begin
                                attack_votes <= attack_votes + 1;
                            end
                            complete_votes <= complete_votes + 1;
                        end
                    end
                end
                
                // Check if we have all votes for current frame
                if (complete_votes == TREE_COUNT) begin
                    state <= VOTING;
                end
            end
            
            COLLECTING: begin
                // Just collect tree outputs until we have them all
                for (j = 0; j < TREE_COUNT; j = j + 1) begin
                    if (tree_prediction_valids[j]) begin
                        if (tree_frame_id[j] == current_voting_frame) begin
                            tree_votes[j] <= tree_predictions[j];
                            if (tree_predictions[j]) begin
                                attack_votes <= attack_votes + 1;
                            end
                            complete_votes <= complete_votes + 1;
                        end
                    end
                end
                
                // If we got all votes for current frame, move to voting
                if (complete_votes == TREE_COUNT) begin
                    state <= VOTING;
                end
                
                // Can accept new frames while collecting
                if (ready_for_next && feature_valid) begin
                    frame_id_in <= frame_id_in + 1;
                end
            end
            
            VOTING: begin
                // Determine final prediction based on majority vote
                // Optimize by using pre-counted votes
                if (attack_votes > (TREE_COUNT / 2)) begin
                    prediction_out <= 1; // Attack detected
                end else begin
                    prediction_out <= 0; // Normal
                end
                
                // Output results
                prediction_valid <= 1;
                frame_id_out <= current_voting_frame;
                
                // Move to next frame
                current_voting_frame <= current_voting_frame + 1;
                tree_votes <= 0;
                attack_votes <= 0;
                complete_votes <= 0;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule

// Module for each decision tree with pipeline support
module pipelined_tree #(
    parameter NODE_WIDTH = 120,
    parameter ADDR_WIDTH = 10,
    parameter ROM_DEPTH = 512,
    parameter TREE_INDEX = 0,  // Tree index (0-20)
    parameter PIPELINE_STAGES = 10  // Maximum number of pipeline stages
)(
    input wire clk,
    input wire rst_n,

    // Input features from CAN bus
    input wire [63:0] arbitration_id,
    input wire [63:0] timestamp,
    input wire [63:0] data_field,
    
    input wire feature_valid, // Asserted when a new frame arrives
    input wire [4:0] frame_id_in, // ID of incoming frame
    
    output reg ready_for_next, // Indicates ready for next frame
    output reg prediction_valid, // Indicates valid prediction result
    output reg prediction_out,  // 0: normal, 1: attack
    output reg [4:0] frame_id_out // ID of processed frame
);

// Loop counter and flag declared at module level
integer i;
// reg found_valid_frame; // Unused - removing

// ================== Pipeline Structures ======================
// Replace struct with individual arrays
/* verilator lint_off UNUSEDSIGNAL */
reg [PIPELINE_STAGES-1:0] pipeline_valid; // Only bit 0 is used, but need all bits for reset
/* verilator lint_on UNUSEDSIGNAL */
reg [4:0] pipeline_frame_id [0:PIPELINE_STAGES-1];
reg [ADDR_WIDTH-1:0] pipeline_current_node [0:PIPELINE_STAGES-1];
reg [3:0] pipeline_prediction [0:PIPELINE_STAGES-1];
// reg [0:PIPELINE_STAGES-1] pipeline_is_done; // Unused - removing

// ================== Internal ======================
wire [NODE_WIDTH-1:0] node_data;
reg [ADDR_WIDTH-1:0] read_addr; // Address being read
reg read_enable; // Add read enable signal

// Temporary signals for current node processing
reg [63:0] feature_value;
/* verilator lint_off UNUSEDSIGNAL */
reg [3:0] feature_code; // Used in the state machine
/* verilator lint_on UNUSEDSIGNAL */

// Cache the current node data to avoid re-reading
/* verilator lint_off UNUSEDSIGNAL */
reg [NODE_WIDTH-1:0] current_node_data; // Not all bits are used
/* verilator lint_on UNUSEDSIGNAL */

// Bit position definitions for node parts
// [*hex Node][* hex feature][16 hex threshold][* hex left][* hex right][* hex prediction]
// localparam NODE_ID_MSB = NODE_WIDTH - 1; // Unused - removing
// localparam NODE_ID_LSB = NODE_WIDTH - 12; // Unused - removing
localparam FEATURE_MSB = NODE_WIDTH - 13;  // Adjusted to not refer to unused params
localparam FEATURE_LSB = FEATURE_MSB - 3;
localparam THRESHOLD_MSB = FEATURE_LSB - 1;
localparam THRESHOLD_LSB = THRESHOLD_MSB - 63;
localparam LEFT_CHILD_MSB = THRESHOLD_LSB - 1;
localparam LEFT_CHILD_LSB = LEFT_CHILD_MSB - 11;
localparam RIGHT_CHILD_MSB = LEFT_CHILD_LSB - 1;
localparam RIGHT_CHILD_LSB = RIGHT_CHILD_MSB - 11;
localparam PREDICTION_MSB = RIGHT_CHILD_LSB - 1;
localparam PREDICTION_LSB = RIGHT_CHILD_LSB - 4;

// Add lint control directives for unused bits of current_node_data
/* verilator lint_off UNUSEDSIGNAL */
// These signals have unused bits but are needed for functionality
// ================== Instantiate ROM ====================
tree_weight_rom #(
    .NODE_WIDTH(NODE_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .ROM_DEPTH(ROM_DEPTH),
    .TREE_INDEX(TREE_INDEX)
) u_tree_weight_rom (
    .clk(clk),
    .addr(read_addr),
    .enable(read_enable), // Only read when enabled
    .node_data(node_data)
);
/* verilator lint_on UNUSEDSIGNAL */

// Function to select feature (moved outside procedural block)
function [63:0] select_feature;
input [3:0] fc_param; // Renamed from feature_code to fc_param to avoid naming conflict
begin
    case (fc_param)
        4'h1: select_feature = arbitration_id;  // 1 = arbitration_id
        4'h0: select_feature = timestamp;       // 0 = timestamp
        4'hA: select_feature = data_field;      // A = data_field
        default: select_feature = 64'b0;
    endcase
end
endfunction

// NEW: Function to get root feature directly based on tree index
function [63:0] get_root_feature;
input integer tree_idx;
begin
    case (tree_idx)
        // timestamp: cây số 0,7,9,10,16,17
        0, 7, 9, 10, 16, 17: get_root_feature = timestamp;
        
        // data_field: 1,3,4,8,11,12,13,19
        1, 3, 4, 8, 11, 12, 13, 19: get_root_feature = data_field;
        
        // arbitration_id: 2,5,6,14,18,20
        2, 5, 6, 14, 18, 20: get_root_feature = arbitration_id;
        
        default: get_root_feature = arbitration_id; // Default to arbitration_id
    endcase
end
endfunction

// NEW: Function to get root feature code based on tree index
function [3:0] get_root_feature_code;
input integer tree_idx;
begin
    case (tree_idx)
        // timestamp (0): cây số 0,7,9,10,16,17
        0, 7, 9, 10, 16, 17: get_root_feature_code = 4'h0;
        
        // data_field (A): 1,3,4,8,11,12,13,19
        1, 3, 4, 8, 11, 12, 13, 19: get_root_feature_code = 4'hA;
        
        // arbitration_id (1): 2,5,6,14,18,20
        2, 5, 6, 14, 18, 20: get_root_feature_code = 4'h1;
        
        default: get_root_feature_code = 4'h1; // Default to arbitration_id
    endcase
end
endfunction

// States for decision tree traversal
localparam IDLE = 2'b00;
localparam READ_NODE = 2'b01; 
localparam PROCESS_NODE = 2'b10;
localparam OUTPUT_RESULT = 2'b11;

reg [1:0] tree_state;

// Replace temporary registers with separate wires for each state
wire [11:0] left_child_addr_root;
wire [11:0] right_child_addr_root;
wire [11:0] left_child_addr_nonroot;
wire [11:0] right_child_addr_nonroot;

// Keep the registers for reset purposes only
reg [11:0] left_child_addr;
reg [11:0] right_child_addr;

// ================== Pipeline Control Logic =========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all pipeline stages
        for (i = 0; i < PIPELINE_STAGES; i = i + 1) begin
            pipeline_valid[i] <= 0;
            pipeline_frame_id[i] <= 0;
            pipeline_current_node[i] <= 0;
            pipeline_prediction[i] <= 0;
            // pipeline_is_done[i] <= 0; // Unused - removing
        end
        
        read_addr <= 0;
        read_enable <= 0;
        ready_for_next <= 1;
        prediction_valid <= 0;
        prediction_out <= 0;
        frame_id_out <= 0;
        feature_code <= 0;
        // found_valid_frame <= 0; // Unused - removing
        tree_state <= IDLE;
        current_node_data <= 0;
        left_child_addr <= 0;
        right_child_addr <= 0;
    end else begin
        // State machine for tree traversal
        case (tree_state)
            IDLE: begin
                read_enable <= 0;
                if (!pipeline_valid[0] && feature_valid) begin
                    // Initialize first pipeline stage for new frame
                    pipeline_valid[0] <= 1;
                    pipeline_frame_id[0] <= frame_id_in;
                    pipeline_current_node[0] <= 0; // Start from root node
                    pipeline_prediction[0] <= 0;
                    // pipeline_is_done[0] <= 0; // Unused - removing
                    
                    // Set read address for root node and enable read
                    read_addr <= 0;
                    read_enable <= 1;
                    
                    // Signal frame has been accepted
                    ready_for_next <= 0;
                    
                    // Pre-calculate feature code for root node optimization
                    feature_code <= get_root_feature_code(TREE_INDEX);
                    feature_value <= get_root_feature(TREE_INDEX);
                    
                    tree_state <= READ_NODE;
                end
            end
            
            READ_NODE: begin
                // Latch the node data
                current_node_data <= node_data;
                read_enable <= 0;
                
                // For non-root nodes, we need to extract feature code normally
                if (pipeline_current_node[0] != 0) begin
                    tree_state <= PROCESS_NODE;
                end else begin
                    // For root node, we already have feature_code and feature_value
                    // Skip the extraction step and go straight to comparison
                    
                    // Check if it's a leaf node based on feature code or prediction value
                    if (node_data[FEATURE_MSB:FEATURE_LSB] == 4'h3 || 
                        node_data[PREDICTION_MSB:PREDICTION_LSB] != 4'h3) begin
                        // If leaf node, mark as completed
                        pipeline_prediction[0] <= node_data[PREDICTION_MSB:PREDICTION_LSB];
                        // pipeline_is_done[0] <= 1; // Unused - removing
                        tree_state <= OUTPUT_RESULT;
                    end else begin
                        // If internal node, prepare to read next node based on pre-determined feature
                        if (feature_value <= node_data[THRESHOLD_MSB:THRESHOLD_LSB]) begin
                            pipeline_current_node[0] <= left_child_addr_root[ADDR_WIDTH-1:0];
                            read_addr <= left_child_addr_root[ADDR_WIDTH-1:0];
                        end else begin
                            pipeline_current_node[0] <= right_child_addr_root[ADDR_WIDTH-1:0];
                            read_addr <= right_child_addr_root[ADDR_WIDTH-1:0];
                        end
                        read_enable <= 1;
                        tree_state <= READ_NODE;
                    end
                end
            end
            
            PROCESS_NODE: begin
                // Only for non-root nodes
                // Extract feature code from current node
                feature_code <= current_node_data[FEATURE_MSB:FEATURE_LSB];
                
                // Check if it's a leaf node based on feature code or prediction value
                if (current_node_data[FEATURE_MSB:FEATURE_LSB] == 4'h3 || 
                    current_node_data[PREDICTION_MSB:PREDICTION_LSB] != 4'h3) begin
                    // If leaf node, mark as completed
                    pipeline_prediction[0] <= current_node_data[PREDICTION_MSB:PREDICTION_LSB];
                    // pipeline_is_done[0] <= 1; // Unused - removing
                    tree_state <= OUTPUT_RESULT;
                end else begin
                    // Get feature value for comparison (only for non-leaf nodes)
                    feature_value <= select_feature(current_node_data[FEATURE_MSB:FEATURE_LSB]);
                    
                    // If internal node, prepare to read next node
                    if (select_feature(current_node_data[FEATURE_MSB:FEATURE_LSB]) <= current_node_data[THRESHOLD_MSB:THRESHOLD_LSB]) begin
                        pipeline_current_node[0] <= left_child_addr_nonroot[ADDR_WIDTH-1:0];
                        read_addr <= left_child_addr_nonroot[ADDR_WIDTH-1:0];
                    end else begin
                        pipeline_current_node[0] <= right_child_addr_nonroot[ADDR_WIDTH-1:0];
                        read_addr <= right_child_addr_nonroot[ADDR_WIDTH-1:0];
                    end
                    read_enable <= 1;
                    tree_state <= READ_NODE;
                end
            end
            
            OUTPUT_RESULT: begin
                // Ready to accept next frame
                ready_for_next <= 1;
                
                // Output prediction
                prediction_valid <= 1;
                prediction_out <= pipeline_prediction[0][0]; // Bit 0 of prediction
                frame_id_out <= pipeline_frame_id[0];
                
                // Clear the pipeline stage
                pipeline_valid[0] <= 0;
                tree_state <= IDLE;
            end
        endcase
        
        // Reset valid signal after each cycle if needed
        if (prediction_valid) begin
            prediction_valid <= 0;
        end
    end
end

// Continuous assignments for immediate calculation
assign left_child_addr_root = node_data[LEFT_CHILD_MSB:LEFT_CHILD_LSB] & 12'hFFF;
assign right_child_addr_root = node_data[RIGHT_CHILD_MSB:RIGHT_CHILD_LSB] & 12'hFFF;
assign left_child_addr_nonroot = current_node_data[LEFT_CHILD_MSB:LEFT_CHILD_LSB] & 12'hFFF;
assign right_child_addr_nonroot = current_node_data[RIGHT_CHILD_MSB:RIGHT_CHILD_LSB] & 12'hFFF;

endmodule

// ROM module with tree index
module tree_weight_rom #(
    parameter NODE_WIDTH = 120,
    parameter ADDR_WIDTH = 10,
    parameter ROM_DEPTH = 512,
    parameter TREE_INDEX = 0
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire enable,  // Add enable signal
    output reg [NODE_WIDTH-1:0] node_data
);

// Get accurate node count for each tree
function integer get_tree_depth;
input integer index;
begin
    case (index)
        0: get_tree_depth = 223;  // Cập nhật đúng số node
        1: get_tree_depth = 373;  // Cập nhật đúng số node
        2: get_tree_depth = 247;  // Cập nhật đúng số node
        3: get_tree_depth = 301;  // Cập nhật đúng số node
        4: get_tree_depth = 295;  // Cập nhật đúng số node
        5: get_tree_depth = 223;  // Cập nhật đúng số node
        6: get_tree_depth = 245;  // Cập nhật đúng số node
        7: get_tree_depth = 213;  // Cập nhật đúng số node
        8: get_tree_depth = 287;  // Cập nhật đúng số node
        9: get_tree_depth = 253;  // Cập nhật đúng số node
        10: get_tree_depth = 321; // Cập nhật đúng số node
        11: get_tree_depth = 263; // Cập nhật đúng số node
        12: get_tree_depth = 319; // Cập nhật đúng số node
        13: get_tree_depth = 303; // Cập nhật đúng số node
        14: get_tree_depth = 215; // Cập nhật đúng số node
        15: get_tree_depth = 231; // Cập nhật đúng số node
        16: get_tree_depth = 355; // Cập nhật đúng số node
        17: get_tree_depth = 245; // Cập nhật đúng số node
        18: get_tree_depth = 227; // Cập nhật đúng số node
        19: get_tree_depth = 377; // Cập nhật đúng số node
        20: get_tree_depth = 259; // Cập nhật đúng số node
        default: get_tree_depth = 250;
    endcase
end
endfunction

// Wire to connect to the appropriate tree ROM based on TREE_INDEX
wire [NODE_WIDTH-1:0] rom_data;

// Use the tree index to instantiate the correct tree ROM
generate
    case (TREE_INDEX)
        0: begin : gen_tree_0
            tree_rom_0 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        1: begin : gen_tree_1
            tree_rom_1 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        2: begin : gen_tree_2
            tree_rom_2 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        3: begin : gen_tree_3
            tree_rom_3 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        4: begin : gen_tree_4
            tree_rom_4 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        5: begin : gen_tree_5
            tree_rom_5 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        6: begin : gen_tree_6
            tree_rom_6 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        7: begin : gen_tree_7
            tree_rom_7 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        8: begin : gen_tree_8
            tree_rom_8 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        9: begin : gen_tree_9
            tree_rom_9 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        10: begin : gen_tree_10
            tree_rom_10 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        11: begin : gen_tree_11
            tree_rom_11 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        12: begin : gen_tree_12
            tree_rom_12 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        13: begin : gen_tree_13
            tree_rom_13 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        14: begin : gen_tree_14
            tree_rom_14 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        15: begin : gen_tree_15
            tree_rom_15 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        16: begin : gen_tree_16
            tree_rom_16 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        17: begin : gen_tree_17
            tree_rom_17 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        18: begin : gen_tree_18
            tree_rom_18 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        19: begin : gen_tree_19
            tree_rom_19 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        20: begin : gen_tree_20
            tree_rom_20 #(
                .NODE_WIDTH(NODE_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ROM_DEPTH(ROM_DEPTH)
            ) u_tree_rom (
                .clk(clk),
                .addr(addr),
                .node_data(rom_data)
            );
        end
        default: begin : gen_default
            // Default case provides zeros
            assign rom_data = {NODE_WIDTH{1'b0}};
        end
    endcase
endgenerate

// Cached ROM data to speed up simulation
reg [NODE_WIDTH-1:0] cached_data;
reg [ADDR_WIDTH-1:0] cached_addr;
reg cache_valid;

// Initialize cache values
initial begin
    cached_data = {NODE_WIDTH{1'b0}};
    cached_addr = {ADDR_WIDTH{1'b0}};
    cache_valid = 0;
end

always @(posedge clk) begin
    // Only read when enabled to save simulation time
    if (enable) begin
        // Check if the address is already cached
        if (cache_valid && cached_addr == addr) begin
            node_data <= cached_data;
        end else if ({22'd0, addr} < get_tree_depth(TREE_INDEX)) begin
            cached_data <= rom_data;
            cached_addr <= addr;
            cache_valid <= 1;
            node_data <= rom_data;
        end else begin
            node_data <= {NODE_WIDTH{1'b0}};
            cache_valid <= 0;
        end
    end
end

endmodule 
