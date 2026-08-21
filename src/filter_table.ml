(** The filter rules, in one place so the RTL generator and the test bench can
    never disagree about them.

    These are ordinary OCaml values. At elaboration time they become constant
    comparators in the netlist -- change this list, regenerate, and the hardware
    changes. That is the part of the design that would be awkward in Verilog,
    where the table would have to be either a hand-written cascade of
    [localparam]s or a runtime-loaded memory.

    The addresses below are UDP multicast groups, the shape of traffic a market
    data feed handler would classify. *)

let default : Ref_model.entry list =
  [ { dst_ip = 0xefc00001 (* 239.192.0.1 *); dst_port = 15000; channel = 0 }
  ; { dst_ip = 0xefc00002 (* 239.192.0.2 *); dst_port = 15001; channel = 1 }
  ; { dst_ip = 0xefc00003 (* 239.192.0.3 *); dst_port = 15002; channel = 2 }
  ; { dst_ip = 0xc0a80102 (* 192.168.1.2  *); dst_port = 4321; channel = 3 }
  ]

(** Datapath widths the project builds and verifies. 8 bytes at 156.25 MHz is
    10 GbE line rate; 64 bytes is the width a 400G MAC would present. *)
let widths = [ 4; 8; 16; 32; 64 ]
