# Random Forest Top Level SDC File
# Timing constraints for random_forest_top_ver2 design

# Set clock period and port
set ::env(CLOCK_PERIOD) "10.0"
set ::env(CLOCK_PORT) "clk"

# Create clock
create_clock -name clk -period 10.0 [get_ports clk]

# Set input delays for all input ports
set_input_delay 2.0 -clock clk [get_ports {arbitration_id[*]}]
set_input_delay 2.0 -clock clk [get_ports {timestamp[*]}]
set_input_delay 2.0 -clock clk [get_ports {data_field[*]}]
set_input_delay 2.0 -clock clk [get_ports feature_valid]
set_input_delay 2.0 -clock clk [get_ports rst_n]

# Set output delays for all output ports
set_output_delay 2.0 -clock clk [get_ports prediction_valid]
set_output_delay 2.0 -clock clk [get_ports prediction_out]
set_output_delay 2.0 -clock clk [get_ports {frame_id_out[*]}]
set_output_delay 2.0 -clock clk [get_ports ready_for_next]

# Set max delay for combinational paths
set_max_delay 10.0 -from [all_inputs] -to [all_outputs]

# Set false paths for reset
set_false_path -from [get_ports rst_n]

# Set multicycle paths for tree processing
# Tree processing paths may take multiple cycles
set_multicycle_path 2 -setup -through [get_nets *tree_*]
set_multicycle_path 1 -hold -through [get_nets *tree_*]

# Set multicycle paths for voting logic
set_multicycle_path 2 -setup -through [get_nets *voting_*]
set_multicycle_path 1 -hold -through [get_nets *voting_*]

# Set clock uncertainty
set_clock_uncertainty 0.1 [get_clocks clk]

# Set transition time constraints
set_max_transition 0.5 [current_design]

# Set load capacitance constraints
set_load 0.1 [all_outputs]

# Set driving cell constraints
set_drive 1 [all_inputs]

# Set area constraints
set_max_area 0

# Set power constraints
set_max_dynamic_power 0
set_max_leakage_power 0

# Set timing exceptions for pipeline stages
set_multicycle_path 2 -setup -through [get_nets *pipeline_*]
set_multicycle_path 1 -hold -through [get_nets *pipeline_*]

# Set timing exceptions for ROM access
set_multicycle_path 2 -setup -through [get_nets *rom_*]
set_multicycle_path 1 -hold -through [get_nets *rom_*]

# Set timing exceptions for feature processing
set_multicycle_path 2 -setup -through [get_nets *feature_*]
set_multicycle_path 1 -hold -through [get_nets *feature_*]

# Set timing exceptions for prediction logic
set_multicycle_path 2 -setup -through [get_nets *prediction_*]
set_multicycle_path 1 -hold -through [get_nets *prediction_*]