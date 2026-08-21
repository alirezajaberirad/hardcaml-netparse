# Out-of-context implementation of every netparse variant, and a CSV of the
# results.
#
# Numbers are taken after place-and-route, not after synthesis. Synthesis
# estimates on a small core are optimistic enough to be misleading; if the
# README is going to quote an Fmax, it should be one that survived routing.
#
# Usage:
#   vivado -mode batch -source synth.tcl -tclargs <rtl_dir> <out_csv> [part]

set rtl_dir [lindex $argv 0]
set out_csv [lindex $argv 1]
set want_part [lindex $argv 2]

# Aggressive target so the design is always timing-limited: Fmax is then
# recovered from the slack rather than being clipped at the requested period.
set period 2.0

# --- pick a part -------------------------------------------------------------
set candidates [list]
if {$want_part ne ""} { lappend candidates $want_part }
lappend candidates \
    xc7a200tfbg484-3 xc7a200tffg1156-3 xc7a100tcsg324-3 \
    xc7k160tfbg484-3 xc7a35tcpg236-3

set part ""
foreach c $candidates {
    if {[llength [get_parts -quiet $c]] > 0} { set part $c; break }
}
if {$part eq ""} {
    set part [lindex [lsort [get_parts]] 0]
    puts "WARNING: no preferred part available, falling back to $part"
}
puts "INFO: using part $part"

set fh [open $out_csv w]
puts $fh "datapath_bits,beats,acc_bits,lut,ff,fmax_mhz,wns_ns,part"

foreach w {4 8 16 32 64} {
    set top netparse_w$w
    set src $rtl_dir/$top.v
    if {![file exists $src]} {
        puts "WARNING: $src missing, skipping"
        continue
    }
    puts "=============================================================="
    puts "INFO: implementing $top ([expr {$w * 8}]-bit datapath)"
    puts "=============================================================="

    create_project -in_memory -part $part
    read_verilog $src
    # out_of_context: this is a core, not a chip -- no I/O buffers, no pinout.
    synth_design -top $top -part $part -mode out_of_context
    create_clock -period $period -name clk [get_ports clock]

    opt_design
    place_design
    phys_opt_design
    route_design

    set lut [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == LUT}]]
    set ff  [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]

    set paths [get_timing_paths -quiet -max_paths 1 -nworst 1 -setup]
    if {[llength $paths] > 0} {
        set wns [get_property SLACK [lindex $paths 0]]
    } else {
        set wns 0.0
    }
    # Achievable period = requested period minus whatever slack we had left.
    set achieved [expr {$period - $wns}]
    if {$achieved <= 0} { set achieved 0.001 }
    set fmax [expr {1000.0 / $achieved}]

    puts [format "RESULT %s: LUT=%d FF=%d WNS=%.3f ns Fmax=%.1f MHz" \
              $top $lut $ff $wns $fmax]
    puts $fh [format "%d,%d,%d,%d,%d,%.1f,%.3f,%s" \
                  [expr {$w * 8}] \
                  [expr {(42 + $w - 1) / $w}] \
                  [expr {(((42 + $w - 1) / $w) * $w) * 8}] \
                  $lut $ff $fmax $wns $part]
    flush $fh

    close_project
}

close $fh
puts "INFO: wrote $out_csv"
