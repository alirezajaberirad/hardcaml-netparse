# Design Notes — hardcaml-netparse

A line-rate Ethernet / IPv4 / UDP packet parser and filter, written in
[Hardcaml](https://github.com/janestreet/hardcaml) (an OCaml hardware
description library), generating synthesizable Verilog.

This document explains *why* the design looks the way it does. Read it before
reading the source.

---

## 1. The problem

An FPGA sitting on a 10 Gb/s Ethernet link receives a byte stream. At 10 Gb/s the
wire delivers 1.25 GB/s. No FPGA fabric runs at 1.25 GHz, so the MAC presents the
stream **W bytes per clock cycle** instead:

| Datapath width W | Clock needed for 10 GbE | Clock needed for 25 GbE |
| ---------------- | ----------------------- | ----------------------- |
| 4 B  (32 bit)    | 312.50 MHz              | 781.25 MHz (infeasible) |
| 8 B  (64 bit)    | 156.25 MHz              | 390.63 MHz              |
| 16 B (128 bit)   | 78.125 MHz              | 195.31 MHz              |
| 32 B (256 bit)   | 39.06 MHz               | 97.66 MHz               |

This is the fundamental trade of line-rate packet processing: **you buy timing
slack with area**. Wider datapath, slower clock, more logic. The point of this
project is to make W a parameter and then *measure* that trade in Vivado.

The job is to pull the header fields out of that stream and decide, per packet,
whether to keep it and where to send it — without ever stalling, because the wire
does not stop.

## 2. Why header parsing is harder than it looks

The headers we care about sit at fixed byte offsets from the start of frame:

```
offset  0 .. 13   Ethernet II   dst MAC(6)  src MAC(6)  ethertype(2)
offset 14 .. 33   IPv4          ver/IHL, ..., proto, checksum, src IP, dst IP
offset 34 .. 41   UDP           src port(2) dst port(2) length(2) checksum(2)
                                                         ^ header ends at byte 41
```

42 bytes of header. Now notice what happens for W = 8:

```
beat 0: bytes  0.. 7   dst MAC, part of src MAC
beat 1: bytes  8..15   rest of src MAC, ethertype, first 2 bytes of IPv4
beat 2: bytes 16..23   IPv4 middle
beat 3: bytes 24..31   IPv4 incl. src IP
beat 4: bytes 32..39   end of dst IP, UDP src/dst port
beat 5: bytes 40..41   UDP length, checksum   <-- header completes mid-beat
```

The ethertype straddles the beat 1/2 boundary, the destination IP straddles beat
3/4, and the UDP ports straddle beat 4. **Change W and every one of those
straddles moves.**

The naive approach — a state machine that byte-muxes each field out of whichever
beat it landed in — produces a rat's nest of case logic that must be rewritten
from scratch for every W. This is exactly the kind of code that gets written once
in Verilog, never touched again, and quietly breaks when someone adds VLAN tags.

## 3. The approach: accumulate, then slice

Instead of extracting fields *as they arrive*, shift arriving beats into one wide
**header accumulator** register, and only once the whole header window has landed,
slice every field out of it combinationally.

```
             W bytes/beat
 AXI-S  ──────────────────>  [ byte-swap ]  ──>  +----------------------+
 tdata                                           |  header accumulator  |
                                                 |     ACC_BITS wide    |
                                                 +----------+-----------+
                                                            | (fields sliced at
                                                            |  fixed offsets)
                                         +------------------+------------------+
                                         v                                     v
                                  IPv4 checksum                          field extract
                                  (adder tree)                        (ethertype, proto,
                                         |                              dst IP, dst port)
                                         +------------------+------------------+
                                                            v
                                                     match table (N entries,
                                                     parallel compare)
                                                            v
                                                   verdict: pass/drop + channel
```

Let `N_BEATS = ceil(42 / W)` and `ACC_BYTES = N_BEATS * W`. Each beat does:

```
acc <= (acc << (W*8)) | swapped_beat
```

After `N_BEATS` beats, packet byte `k` is *always* at accumulator bits

```
[ ACC_BITS - k*8 - 1  :  ACC_BITS - (k+1)*8 ]
```

**for every W.** The straddling problem disappears by construction: there is
exactly one shift register and one set of constant slice offsets, and neither
depends on the datapath width.

That single insight is what makes the design parameterizable at all. It costs one
register of `ACC_BYTES` and buys a design that is correct for W = 4, 8, 16, 32 and
64 from one source.

### Why the byte swap

AXI4-Stream carries the *first byte on the wire* in the *least significant* lane,
`tdata[7:0]`. Network headers are big-endian, and we want packet byte 0 at the
**top** of the accumulator so the slice offsets above come out natural. So each
beat is byte-reversed on the way in.

Byte-order confusion is the single most common bug in packet parsers. The
convention is stated once, in `Packet_defs`, and never re-derived.

## 4. IPv4 header checksum

The IPv4 checksum is a 16-bit one's-complement sum over the 20-byte header. To
*verify*, sum all ten 16-bit words **including** the checksum field; a valid
header gives `0xFFFF`.

Because the entire header is already sitting in a register, this is a flat
10-input adder tree rather than the serial accumulator you would need if you were
checksumming on the fly. Ten 16-bit words sum to at most `10 * 65535 = 655350`,
which needs 20 bits, so carries are folded twice:

```
sum20 = w0 + w1 + ... + w9           (20 bits, no information lost)
fold1 = sum20[15:0] + sum20[19:16]   (17 bits)
fold2 = fold1[15:0] + fold1[16]      (16 bits)
ok    = (fold2 == 0xFFFF)
```

The tree is registered in the middle so it does not become the critical path at
the widest datapaths.

## 5. Match table

The filter holds N entries of `(dst_ip, dst_port) -> channel`. All N entries are
compared **in parallel** — a fully associative match — because a packet must be
classified in fixed time. A hash table or CAM would be the right call at hundreds
of entries; at the handful we need, parallel compare is smaller and has no
collision behaviour to reason about.

The table is supplied as an **OCaml list at elaboration time** and becomes constant
comparators in the netlist. This is the part of the design that would be painful
in Verilog: the rules live in a real data structure in a real language, and the
hardware is generated from them.

## 6. What is deliberately *not* handled

Scope boundaries, chosen so the thing could be finished and verified properly
rather than half-built in six directions:

- **VLAN tags (802.1Q).** A tagged frame shifts every subsequent offset by 4 bytes.
  Handled by *detecting* ethertype `0x8100` and marking the packet unsupported, not
  by re-parsing. Supporting it properly means a second set of slice offsets selected
  by a mux — a natural extension, and a good exercise.
- **IPv4 options (IHL > 5).** Same story: a variable header length moves the UDP
  offsets. Detected and rejected.
- **IP fragmentation.** Fragments are detected and rejected rather than reassembled;
  reassembly needs buffering and per-flow state, which is a different project.
- **UDP checksum.** Requires the payload, not just the header, so it cannot be done
  from the accumulator alone. The IPv4 *header* checksum is done.
- **Backpressure.** The parser never de-asserts `tready`. Real MACs cannot be
  back-pressured anyway — a receive path that stalls drops packets — so an
  unconditionally-ready design is the honest architecture for an ingress parser.
- **Runt / oversized frames.** A packet shorter than 42 bytes ends before the header
  completes; it is flagged `short` and dropped.

## 7. Verification strategy

Two independent implementations, compared against each other:

1. A **reference model in pure OCaml** that parses a `bytes` buffer the obvious way
   — no hardware concepts, just array indexing. Easy to read, easy to trust.
2. The **Hardcaml RTL**, simulated beat by beat.

A generator builds random but well-formed packets (random MACs, IPs, ports, payload
lengths, correct checksums) plus a set of adversarial ones (bad checksum, wrong
ethertype, VLAN tagged, truncated, minimum-length, maximum-length). Every packet is
pushed through both, and the verdicts must agree — at every datapath width.

The interesting property is that **the same packet must produce the same verdict for
W = 4, 8, 16, 32 and 64**. Datapath width is an implementation detail; it must not be
observable in behaviour. That single property catches essentially every straddling
bug, which is why the test suite leans on it.

## 8. Results

See the generated table in the top-level `README.md` for Fmax and resource usage per
datapath width, from Vivado synthesis.
