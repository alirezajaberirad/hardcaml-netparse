# hardcaml-netparse

[![ci](https://github.com/alirezajaberirad/hardcaml-netparse/actions/workflows/ci.yml/badge.svg)](https://github.com/alirezajaberirad/hardcaml-netparse/actions/workflows/ci.yml)

A line-rate Ethernet / IPv4 / UDP packet parser and filter, written in
[Hardcaml](https://github.com/janestreet/hardcaml) — Jane Street's OCaml
hardware description library — and synthesized to a Xilinx 7-series FPGA.

**The datapath width is an OCaml parameter.** One source file generates the
32-, 64-, 128-, 256- and 512-bit variants, each structurally different in RTL,
all verified against the same reference model.

---

## What it does

Packets arrive as an AXI4-Stream at *W* bytes per clock. The core pulls the
Ethernet, IPv4 and UDP headers out of the stream, validates them, and classifies
each packet against a filter table of `(dst_ip, dst_port) → channel` rules —
the shape of work an FPGA market-data feed handler does on every multicast
packet it sees.

Per packet it emits a verdict: pass or drop, the matched channel, and a
breakdown of why a packet was rejected (runt, VLAN-tagged, not IPv4, IPv4
options present, not UDP, fragmented, bad header checksum).

The verdict arrives 3 cycles after the last header beat. There is no `tready`
output — the core is unconditionally ready and never stalls — so throughput is
one packet per `ceil(42 / W)` beats regardless of verdict: a rejected packet
costs exactly as much as an accepted one.

## Why it is written in Hardcaml

Header fields sit at fixed *byte* offsets, but arrive in *W-byte* beats. At
W = 8 the ethertype straddles one beat boundary and the destination IP straddles
another; change W and every straddle moves. Written directly in Verilog, this
becomes per-width byte-muxing logic that has to be rewritten from scratch for
each datapath width.

Instead, arriving beats are shifted into a wide header accumulator MSB-first, so
packet byte *k* always lands at a bit offset **independent of W** — and the
straddling problem disappears by construction. Because W is an ordinary OCaml
integer, the accumulator size, beat count and slice offsets are all *computed*
at elaboration time rather than hand-maintained.

The filter table is likewise an ordinary OCaml list
([`src/filter_table.ml`](src/filter_table.ml)) that becomes constant comparators
in the netlist.

- **[doc/DESIGN.md](doc/DESIGN.md)** — the architecture and the reasoning behind
  it: why the accumulator, how the checksum folds, and what is deliberately out
  of scope.
- **[doc/LEARNING.md](doc/LEARNING.md)** — how the OCaml works, the
  elaboration-time mental model Hardcaml depends on, and a walkthrough of the
  one real bug the differential test caught.

## Results

Post-place-and-route, out-of-context, Xilinx Artix-7.

<!-- RESULTS_TABLE_START -->
*Populated by `syn/vivado/synth.tcl` — see below.*
<!-- RESULTS_TABLE_END -->

10 GbE line rate needs 156.25 MHz at a 64-bit datapath; 25 GbE needs 390.6 MHz.

## Verification

Two independent implementations are compared on every packet:

- [`src/ref_model.ml`](src/ref_model.ml) — a pure-OCaml parser that indexes into
  a byte buffer. No hardware concepts; written to be read and trusted.
- [`src/parser_core.ml`](src/parser_core.ml) — the RTL, simulated beat by beat.

**12,715 checks, 0 failures.** The test bench drives:

- a directed corpus — one packet per rejection reason, plus the boundary cases
  where the header exactly fills or just fails to fill the accumulator;
- 2000 randomised well-formed packets from a fixed seed;
- a sweep of every payload length that moves the header's end across a beat
  boundary, and every truncation length from 1 to 42 bytes;
- **wait states** — idle cycles mid-packet, which must not change the verdict;
- **back-to-back streams** — packets with no gaps and no reset between them,
  which must produce exactly one verdict each, in order.

The load-bearing property is **cross-width invariance**: the same packet must
produce the same verdict at every datapath width. Width is an implementation
detail, so any behavioural difference is a mis-sliced field — which is exactly
the bug class the accumulator design exists to prevent. It earned its keep: see
[`doc/LEARNING.md` §5](doc/LEARNING.md) for the one real bug it caught and how
the shape of the failure identified the cause.

## Layout

| Path | |
| --- | --- |
| [`src/packet_defs.ml`](src/packet_defs.ml) | Wire-format offsets and derived geometry, shared by model and RTL |
| [`src/ref_model.ml`](src/ref_model.ml) | Pure-OCaml reference parser |
| [`src/parser_core.ml`](src/parser_core.ml) | The Hardcaml design |
| [`src/packet_gen.ml`](src/packet_gen.ml) | Frame builder: well-formed and adversarial |
| [`src/tb.ml`](src/tb.ml) | Cycle-accurate AXI-Stream test harness |
| [`src/filter_table.ml`](src/filter_table.ml) | Filter rules and the width list |
| [`bin/generate.ml`](bin/generate.ml) | Emits one Verilog file per width |
| [`test/test_netparse.ml`](test/test_netparse.ml) | Differential test |
| [`syn/vivado/synth.tcl`](syn/vivado/synth.tcl) | Out-of-context implementation + CSV |

## Building

Toolchain (Ubuntu, or WSL2 on Windows). `ppx_hardcaml` needs OCaml ≥ 5.1:

```bash
bash syn/setup_toolchain.sh      # opam switch + hardcaml + ppx_hardcaml
```

Build, test, and emit RTL:

```bash
bash syn/build.sh
```

Then implement in Vivado and regenerate the results table:

```bash
vivado -mode batch -source syn/vivado/synth.tcl \
       -tclargs rtl syn/results/results.csv
```

## Scope

Deliberately not handled, and why, in
[doc/DESIGN.md §6](doc/DESIGN.md): VLAN re-parsing, IPv4 options, fragment
reassembly, UDP payload checksum, and backpressure. Each is *detected* and
reported rather than silently mishandled.
