# Learning guide

You are going to be asked to explain this design. This document is the path
from "I have a repo" to "I can defend every line of it."

Read [DESIGN.md](DESIGN.md) first — it covers *what* the hardware does. This one
covers *how the OCaml works* and *what you will be asked*.

---

## 1. The one idea that makes Hardcaml make sense

Hardcaml is not a language that "compiles to Verilog." It is an ordinary OCaml
library whose values happen to be circuit nodes.

```ocaml
let x = a +: b
```

This does not add anything. It allocates a node in a graph that says "an adder,
with `a` and `b` as its inputs" and binds `x` to it. Your OCaml program **runs
once**, at *elaboration time*, and the thing it leaves behind is a netlist.

Everything else follows from that. When you see:

```ocaml
let ip_words =
  List.init 10 (fun k -> field acc ~off:(off_ip + 2 * k) ~len:2)
```

that is not a loop in hardware. `List.init` runs at elaboration and produces ten
separate slice nodes, which all exist simultaneously in silicon. The OCaml `for`
loop is a *code generator*; the hardware is flat and parallel.

The corollary is the reason this project exists: **anything OCaml can compute
before the netlist exists is free.** `n_beats`, `acc_bits`, the slice offsets,
the table comparators — all ordinary OCaml arithmetic over ordinary OCaml
values, evaluated once, baked into the graph.

That is the difference from Verilog. Verilog's `generate`/`localparam` is a
weak, separate metalanguage bolted onto the HDL. In Hardcaml the metalanguage
*is* the language, so `List.fold_right` over a list of filter rules is a normal
thing to write.

## 2. Read the code in this order

| # | File | What to take from it |
|---|------|---------------------|
| 1 | [`src/packet_defs.ml`](../src/packet_defs.ml) | Plain OCaml. No Hardcaml at all. Note `acc_field_range` — the arithmetic that makes width-independence work. |
| 2 | [`src/ref_model.ml`](../src/ref_model.ml) | Plain OCaml again. If you can't state what the hardware should do, you can't check that it does. |
| 3 | [`src/parser_core.ml`](../src/parser_core.ml) | The design. Read `create` top to bottom; it is written in dataflow order. |
| 4 | [`src/tb.ml`](../src/tb.ml) | How a Hardcaml simulation is driven. |
| 5 | [`test/test_netparse.ml`](../test/test_netparse.ml) | What "verified" means here. |

## 3. OCaml features used, and why

**Functors** (`module Make (Cfg : Config) = struct ... end`). A functor is a
function from modules to modules. `Parser_core.Make` takes a module containing
`datapath_bytes` and `table`, and returns a module containing a whole circuit
built around those values. This is *the* parameterization mechanism — the
equivalent of Verilog's `parameter`, except the parameter can be a list, a
function, or any other OCaml value, and it is type-checked.

**Module types** (`module type Config = sig ... end`) are the signatures
functors accept — the interface contract.

**`[@@deriving hardcaml]`** on a record generates the boilerplate that lets
Hardcaml treat that record as a bundle of ports: how to iterate it, its widths,
its names. `[@bits data_bits]` sets a field's width from an ordinary OCaml
value, which is why the interface itself can be width-parameterized.

**Labelled arguments** (`~off`, `~len`, `~f`). At a call site,
`field acc ~off:14 ~len:2` says what `14` and `2` mean. In a file full of
integer offsets this is the difference between readable and unreadable.

**`wire` and `<==`.** OCaml is single-assignment, but hardware has feedback
loops: `hdr_done` gates the accumulator, and the accumulator's completion sets
`hdr_done`. `wire 1` creates an unattached node you can reference before you
drive it, and `<==` attaches it later. Use it *only* for genuine feedback —
reach for it habitually and you lose the compiler's ordering checks.

**A gotcha you will hit.** OCaml resolves a bare record field access to the
*last-defined* record type with that field name. `Ref_model.entry` and
`Ref_model.verdict` both have `dst_ip`, so `lookup` silently inferred the wrong
type until the annotations in `ref_model.ml` were added. Same again in `tb.ml`,
where `result` and the port interface both have `valid`. When a type error
mentions a record you did not expect, this is why.

## 4. Width discipline

Hardcaml will not let you add a 16-bit signal to a 20-bit one. `+:` requires
equal widths and returns that same width — **no automatic growth**, so `a +: b`
on two 16-bit values gives 16 bits and drops the carry. Widening is explicit:
`uresize x 20`.

This is why the checksum is written the way it is. Ten 16-bit words sum to at
most `10 × 0xFFFF = 0x9FFF6`, which needs 20 bits, so every word is `uresize`d
to 20 before summing. Then the carries are folded back in twice. Get this wrong
and you get a checksum that is right for most packets and wrong for the ones
that carry — the worst kind of bug, because random testing nearly finds it.

## 5. The bug that was in this design, and how it showed itself

Worth understanding, because it is the most instructive thing in the git
history (commit `797e9b6`).

The field registers were enabled by `header_complete`. But `acc` is a
*register*: on the cycle `header_complete` is high, the final beat is still on
`acc`'s **input**, not its output. So the extraction read the accumulator one
beat stale.

The symptom was beautiful. At W=4 the test reported `dst_ip = 0xC0A80101` —
which is `192.168.1.1`, the *source* address, sitting exactly 4 bytes before the
destination. One beat early. At W=8 the error was 8 bytes, at W=64 the
accumulator was still all zeros. **The error scaled with the beat size**, which
points straight at the accumulator rather than at the offsets.

The fix was to gate extraction on a registered `header_complete`, making the
pipeline three stages instead of two. Read the diff.

The lesson: a differential test against a reference model does not just say
"fail," it hands you the arithmetic of the failure. That is why the reference
model is worth writing.

## 6. Questions you should be able to answer cold

Work through these out loud. If you cannot answer one, that is the part to
re-read.

**Architecture**
1. Why accumulate the header and slice it, rather than extracting fields as they
   arrive? What does the naive version cost you when W changes?
2. Why is the accumulator `n_beats * w` bytes rather than 42 bytes?
3. Why does packet byte *k* land at the same bit offset for every W? Show the
   arithmetic.
4. Why does streaming packets back to back work without clearing the
   accumulator between them? (Hint: it depends on the answer to Q2.)

**Timing and throughput**
5. What clock does a 64-bit datapath need for 10 GbE? For 25 GbE? Derive it.
6. What is the latency from the last header beat to `valid`? Why three stages?
7. Where is the critical path, and how would you shorten it? What does that
   cost?
8. The 32-bit variant does not close 10 GbE timing. Why is that acceptable —
   or is it?

**Protocol**
9. Why is the IPv4 checksum verified by summing *including* the checksum field
   and comparing against `0xFFFF`?
10. Why are the carries folded twice, not once?
11. Why can the UDP checksum not be computed here?
12. What exactly changes if a VLAN tag is present, and what would you add?

**Verification**
13. What does cross-width invariance catch that a single-width test does not?
14. Why is a zero-length packet excluded from the sweep?
15. What is *not* covered by this test suite?

## 7. Honest gaps — know these before someone finds them

A reviewer will look for what is missing. Better that you name it first.

- **No backpressure.** `tready` is never de-asserted. Defensible for an ingress
  parser (see DESIGN.md §6), but know that it is a choice, not an oversight.
- **The filter table is compile-time.** Real systems reconfigure rules at
  runtime, which means an AXI4-Lite register interface and a small RAM. The
  compile-time version makes a better *language* argument and a weaker
  *product* argument.
- **No board.** These are post-route numbers from Vivado, not measurements on
  silicon. Say "post-route", never "measured."
- **VLAN, IPv4 options, and fragments are rejected, not handled.**
- **Payload is untouched.** The core classifies; it does not forward, buffer, or
  reassemble.

## 8. Where to take it next

Roughly in order of value-per-hour:

1. **Pipeline the checksum adder tree** across two stages and re-run synthesis.
   Produces a before/after Fmax table — the single most convincing artifact a
   timing-closure story can have.
2. **VLAN support.** A second set of slice offsets selected by a mux on
   ethertype. Small, and it exercises exactly the parameterization idea.
3. **Runtime-writable filter table** over AXI4-Lite. Turns the toy into
   something deployable.
4. **A second reference implementation in Python/scapy**, fed real pcap
   captures. Catches wire-format misunderstandings the OCaml model shares by
   construction.
5. **`hardcaml_waveterm`** for waveform dumps in the tests
   (`WITH_WAVETERM=1 bash syn/setup_toolchain.sh`).

## 9. Toolchain quick reference

```bash
# One-time
wsl --install -d Ubuntu-24.04
bash syn/setup_toolchain.sh          # opam switch + hardcaml (needs OCaml >= 5.1)

# Every time
bash syn/test.sh                     # build + differential test
bash syn/build.sh                    # the above, plus regenerate rtl/*.v

# Synthesis (Windows-side Vivado, reading the generated Verilog)
vivado -mode batch -source syn/vivado/synth.tcl \
       -tclargs rtl syn/results/results.csv
```

The OCaml toolchain lives in WSL; Vivado runs on Windows and reads the generated
`.v` files across `/mnt/c`. `ppx_hardcaml` requires OCaml ≥ 5.1, which is why
the switch is built from source rather than reusing Ubuntu's 4.14.
