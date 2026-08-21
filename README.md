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

Further reading:

- **[doc/DESIGN.md](doc/DESIGN.md)** — the architecture and the reasoning behind
  it: why the accumulator, how the checksum folds, and what is deliberately out
  of scope.
- **[doc/LEARNING.md](doc/LEARNING.md)** — how the OCaml works, the
  elaboration-time mental model Hardcaml depends on, and a walkthrough of the
  one real bug the differential test caught.

## Results

<!-- RESULTS_TABLE_START -->
Post-place-and-route, out-of-context, `xc7a200tfbg484-3` (Artix-7, speed grade -3).

| Datapath | Header beats | LUT | FF | Fmax | 10 GbE | 25 GbE |
| ---: | ---: | ---: | ---: | ---: | :---: | :---: |
| 32-bit | 11 | 244 | 368 | 206 MHz | no | no |
| 64-bit | 6 | 226 | 428 | 207 MHz | **yes** | no |
| 128-bit | 3 | 240 | 427 | 213 MHz | **yes** | **yes** |
| 256-bit | 2 | 266 | 490 | 207 MHz | **yes** | **yes** |
| 512-bit | 1 | 330 | 329 | 203 MHz | **yes** | **yes** |

Sustaining a line rate needs `rate / datapath_width`: 156 MHz for 10 GbE at 64-bit, 391 MHz for 25 GbE at 64-bit. Artix-7 is a low-cost 28 nm family and the -3 grade is its fastest; the same RTL on an UltraScale+ part would clock considerably higher.

### Finding the critical path — including one wrong turn

Fmax barely moves across a 16x range of datapath widths. That is the useful clue: the limit is **width-independent**, so it lives in a block that is identical at every width rather than in the datapath.

The first guess was the IPv4 checksum's adder tree. It was summing the ten header words with `List.fold_left ( +: )`, which builds a *linear chain ten adders deep* rather than a `ceil(log2 10) = 4` deep tree. Restructuring it did nothing:

| Datapath | Fmax, linear chain | Fmax, balanced tree | Change |
| ---: | ---: | ---: | ---: |
| 32-bit | 206.1 MHz | 205.7 MHz | -0.2% |
| 64-bit | 207.6 MHz | 206.8 MHz | -0.4% |
| 128-bit | 200.4 MHz | 213.1 MHz | +6.3% |
| 256-bit | 212.4 MHz | 207.3 MHz | -2.4% |
| 512-bit | 214.0 MHz | 203.1 MHz | -5.1% |
| **mean** | **208.1 MHz** | **207.2 MHz** | **-0.4%** |

Mixed signs, a few percent either way, and a mean that does not move: that is run-to-run placement noise, not an improvement. Vivado restructures arithmetic during synthesis, so the shape of the OCaml fold never reached the netlist in the first place. **A difference smaller than the spread between runs is not evidence of anything** — the honest read is "no effect".

So the path got measured instead of guessed, with [`syn/vivado/critpath.tcl`](syn/vivado/critpath.tcl). On the 64-bit variant: **13 logic levels, 4.797 ns**, from `_90_reg[17]` to `_112_reg`. In the generated Verilog `_90` is the 20-bit `s1_csum_sum` register — sliced as `_90[19:16]` and `_90[15:0]`, which is exactly the carry fold — and `_112` drives `err_bad_checksum`.

The limit is therefore **stage 2**: fold, fold again, compare against `0xffff`, then OR into the malformed tree and register. Not stage 1's adder tree, which is precisely why restructuring it changed nothing. The fix is a pipeline register between the fold and the compare, at the cost of one more cycle of latency.

The restructure was kept anyway: it is functionally identical (addition is associative, and a 20-bit accumulator cannot overflow on ten 16-bit inputs, so no intermediate truncates) and it expresses the intent correctly even though this tool would have done it regardless.
<!-- RESULTS_TABLE_END -->

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
# once as root for the apt packages, then as your own user for the switch
wsl -d Ubuntu-24.04 -u root -- bash syn/setup_toolchain.sh
bash syn/setup_toolchain.sh
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
