# Report the actual worst-case timing path for one variant, with enough detail
# to name the logic that limits Fmax.
#
# Written because inferring the critical path from Fmax-versus-width was not
# good enough: the flat Fmax across widths correctly said "width-independent",
# but the guess as to *which* width-independent block was wrong. Vivado
# restructures adder chains during synthesis, so the shape of the OCaml fold
# does not survive to the netlist.
#
# Usage:
#   vivado -mode batch -source critpath.tcl -tclargs <rtl_dir> <top> [part]

set rtl_dir [lindex $argv 0]
set top     [lindex $argv 1]
set part    [lindex $argv 2]
if {$part eq ""} { set part xc7a200tfbg484-3 }

create_project -in_memory -part $part
read_verilog $rtl_dir/$top.v
synth_design -top $top -part $part -mode out_of_context
create_clock -period 2.0 -name clk [get_ports clock]
opt_design
place_design
phys_opt_design
route_design

puts "=============================================================="
puts "CRITICAL PATHS for $top on $part"
puts "=============================================================="

set paths [get_timing_paths -max_paths 5 -nworst 5 -setup]
set n 0
foreach p $paths {
    incr n
    puts ""
    puts "--- path $n ---"
    puts [format "  slack        : %.3f ns" [get_property SLACK $p]]
    puts [format "  data path    : %.3f ns" [get_property DATAPATH_DELAY $p]]
    puts [format "  logic levels : %d"      [get_property LOGIC_LEVELS $p]]
    puts "  startpoint   : [get_property STARTPOINT_PIN $p]"
    puts "  endpoint     : [get_property ENDPOINT_PIN $p]"
}

puts ""
puts "=== full detail for the worst path ==="
report_timing -max_paths 1 -nworst 1 -setup -input_pins
