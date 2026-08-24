# Learning guide

A guided read of the source, for anyone picking this repo up — including its
author six months from now. It goes from "I have cloned this" to "I understand
why each decision was made."

Read [DESIGN.md](DESIGN.md) first: it covers *what* the hardware does. This one
covers *how the OCaml works*, walks through the two mistakes worth learning
from, and ends with a self-test.

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

## 5b. The optimisation that wasn't

The second instructive episode in the history, and the one that generalises
beyond this project.

Synthesis came back with Fmax essentially flat across a **16× range** of
datapath widths: 206, 208, 200, 212, 214 MHz. That is a real clue, and the
inference from it was sound — a limit that does not move with the datapath must
live in a block that is identical at every width.

The guess as to *which* block was wrong. The suspect was the checksum adder
tree, which was summing ten words with `List.fold_left ( +: )` — a **linear
chain ten adders deep** rather than a depth-4 tree. That looks damning. It was
restructured into a balanced tree, and synthesis re-run:

| Datapath | linear | balanced | change |
| ---: | ---: | ---: | ---: |
| 32-bit | 206.1 | 205.7 | −0.2% |
| 64-bit | 207.6 | 206.8 | −0.4% |
| 128-bit | 200.4 | 213.1 | +6.3% |
| 256-bit | 212.4 | 207.3 | −2.4% |
| 512-bit | 214.0 | 203.1 | −5.1% |
| **mean** | **208.1** | **207.2** | **−0.4%** |

Nothing. **Mixed signs and a stationary mean is placement noise.** Vivado
restructures arithmetic during synthesis, so the shape of the OCaml fold never
reached the netlist to begin with.

Two lessons, and they are the ones to actually carry:

1. **A difference smaller than the spread between runs is not a result.** Had
   only the 128-bit variant been built, the +6.3% would have looked like a
   convincing win. It was noise. Always know your noise floor before you claim
   an improvement — which means running the experiment more than once.
2. **Measure the path; do not infer it.** `syn/vivado/critpath.tcl` reports the
   routed worst path with its endpoints. It says: 13 logic levels, 4.797 ns,
   `_90_reg[17]` → `_112_reg`. Cross-referencing the generated Verilog, `_90` is
   the 20-bit `s1_csum_sum` register (sliced `[19:16]` and `[15:0]` — the carry
   fold) and `_112` drives `err_bad_checksum`. The limit was **stage 2's fold**,
   one pipeline stage downstream of where it was being looked for.

Worth keeping because the reasoning was defensible and the experiment falsified
it anyway. The useful response to that is better data, not a better argument.

## 6. Quiz yourself

A self-test to check the read landed. Work through them out loud; anything you
cannot answer points at the section to go back to.

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
7. Where is the critical path? Name the two registers it runs between, and say
   how you would shorten it and what that costs.
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
16. The balanced-tree change moved the 128-bit variant +6.3%. Why is that not
    a result? What would you need to run to make it one?

## 7. What this core does not do

Stated plainly, so nobody has to reverse-engineer the boundaries from the source.
Each of these is a deliberate scope decision rather than an oversight.

- **No backpressure.** There is no `tready` port at all — the core is
  unconditionally ready. That is the right architecture for an ingress parser
  (see DESIGN.md §6), but it is a constraint on what can sit downstream: a
  consumer that can stall needs a FIFO between it and this core.
- **The filter table is compile-time.** Real systems reconfigure rules at
  runtime, which means an AXI4-Lite register interface and a small RAM. The
  compile-time version makes a better *language* argument and a weaker
  *product* argument.
- **No board.** Every number here is post-route from Vivado, not measured on
  silicon. The distinction matters: place-and-route models timing, it does not
  observe it.
- **VLAN, IPv4 options, and fragments are rejected, not handled.**
- **Payload is untouched.** The core classifies; it does not forward, buffer, or
  reassemble.

## 8. Where to take it next

Roughly in order of value-per-hour:

1. **Pipeline the checksum fold.** The measured critical path (see §5b) runs
   from the `s1_csum_sum` register through both carry folds, the `0xFFFF`
   compare, and the `malformed` OR-tree into the output register — 13 logic
   levels, 4.797 ns. Putting a register between the fold and the compare should
   split that roughly in half, at the cost of one more cycle of latency. Re-run
   `syn/vivado/synth.tcl` and see whether it moves. **Run it more than once**:
   §5b is the cautionary tale about what happens when you don't.
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
wsl -d Ubuntu-24.04 -u root -- bash syn/setup_toolchain.sh   # apt packages
bash syn/setup_toolchain.sh                                  # your own opam switch

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
