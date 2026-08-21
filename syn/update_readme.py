#!/usr/bin/env python3
"""Rewrite the results table in README.md from the Vivado CSV.

Kept as a script rather than pasted by hand so the published numbers cannot
drift from the ones synthesis actually produced.

    update_readme.py [results.csv] [--baseline baseline.csv]

With --baseline, a second table is emitted comparing Fmax before and after a
change, which is how the checksum-tree restructure is documented.
"""

import argparse
import csv
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
START = "<!-- RESULTS_TABLE_START -->"
END = "<!-- RESULTS_TABLE_END -->"


def required_mhz(datapath_bits, line_rate_gbps):
    """Clock a datapath of this width needs to sustain a given line rate."""
    return line_rate_gbps * 1e9 / datapath_bits / 1e6


def load(path):
    rows = list(csv.DictReader(pathlib.Path(path).read_text().splitlines()))
    if not rows:
        sys.exit(f"no rows in {path}")
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results", nargs="?",
                    default=str(REPO / "syn" / "results" / "results.csv"))
    ap.add_argument("--baseline")
    args = ap.parse_args()

    rows = load(args.results)
    part = rows[0]["part"]

    out = [
        f"Post-place-and-route, out-of-context, `{part}` "
        "(Artix-7, speed grade -3).",
        "",
        "| Datapath | Header beats | LUT | FF | Fmax | 10 GbE | 25 GbE |",
        "| ---: | ---: | ---: | ---: | ---: | :---: | :---: |",
    ]
    for r in rows:
        bits = int(r["datapath_bits"])
        fmax = float(r["fmax_mhz"])
        out.append(
            "| {bits}-bit | {beats} | {lut} | {ff} | {fmax:.0f} MHz | {t10} | {t25} |".format(
                bits=bits,
                beats=r["beats"],
                lut=r["lut"],
                ff=r["ff"],
                fmax=fmax,
                t10="**yes**" if fmax >= required_mhz(bits, 10) else "no",
                t25="**yes**" if fmax >= required_mhz(bits, 25) else "no",
            )
        )
    out += [
        "",
        "Sustaining a line rate needs `rate / datapath_width`: 156 MHz for 10 GbE "
        "at 64-bit, 391 MHz for 25 GbE at 64-bit. Artix-7 is a low-cost 28 nm "
        "family and the -3 grade is its fastest; the same RTL on an UltraScale+ "
        "part would clock considerably higher.",
    ]

    if args.baseline:
        base = {int(r["datapath_bits"]): float(r["fmax_mhz"]) for r in load(args.baseline)}
        pairs = [(int(r["datapath_bits"]), base[int(r["datapath_bits"])],
                  float(r["fmax_mhz"]))
                 for r in rows if int(r["datapath_bits"]) in base]
        old_mean = sum(o for _, o, _ in pairs) / len(pairs)
        new_mean = sum(n for _, _, n in pairs) / len(pairs)

        out += [
            "",
            "### Finding the critical path — including one wrong turn",
            "",
            "Fmax barely moves across a 16x range of datapath widths. That is the "
            "useful clue: the limit is **width-independent**, so it lives in a "
            "block that is identical at every width rather than in the datapath.",
            "",
            "The first guess was the IPv4 checksum's adder tree. It was summing "
            "the ten header words with `List.fold_left ( +: )`, which builds a "
            "*linear chain ten adders deep* rather than a `ceil(log2 10) = 4` "
            "deep tree. Restructuring it did nothing:",
            "",
            "| Datapath | Fmax, linear chain | Fmax, balanced tree | Change |",
            "| ---: | ---: | ---: | ---: |",
        ]
        for bits, old, new in pairs:
            out.append(
                f"| {bits}-bit | {old:.1f} MHz | {new:.1f} MHz | "
                f"{(new - old) / old * 100:+.1f}% |"
            )
        out += [
            f"| **mean** | **{old_mean:.1f} MHz** | **{new_mean:.1f} MHz** | "
            f"**{(new_mean - old_mean) / old_mean * 100:+.1f}%** |",
            "",
            "Mixed signs, a few percent either way, and a mean that does not move: "
            "that is run-to-run placement noise, not an improvement. Vivado "
            "restructures arithmetic during synthesis, so the shape of the OCaml "
            "fold never reached the netlist in the first place. **A difference "
            "smaller than the spread between runs is not evidence of anything** — "
            "the honest read is \"no effect\".",
            "",
            "So the path got measured instead of guessed, with "
            "[`syn/vivado/critpath.tcl`](syn/vivado/critpath.tcl). On the 64-bit "
            "variant: **13 logic levels, 4.797 ns**, from `_90_reg[17]` to "
            "`_112_reg`. In the generated Verilog `_90` is the 20-bit "
            "`s1_csum_sum` register — sliced as `_90[19:16]` and `_90[15:0]`, "
            "which is exactly the carry fold — and `_112` drives "
            "`err_bad_checksum`.",
            "",
            "The limit is therefore **stage 2**: fold, fold again, compare against "
            "`0xffff`, then OR into the malformed tree and register. Not stage 1's "
            "adder tree, which is precisely why restructuring it changed nothing. "
            "The fix is a pipeline register between the fold and the compare, at "
            "the cost of one more cycle of latency.",
            "",
            "The restructure was kept anyway: it is functionally identical "
            "(addition is associative, and a 20-bit accumulator cannot overflow on "
            "ten 16-bit inputs, so no intermediate truncates) and it expresses the "
            "intent correctly even though this tool would have done it regardless.",
        ]

    readme = REPO / "README.md"
    text = readme.read_text(encoding="utf-8")
    before, _, rest = text.partition(START)
    _, _, after = rest.partition(END)
    readme.write_text(
        before + START + "\n" + "\n".join(out) + "\n" + END + after,
        encoding="utf-8",
    )
    print(f"updated {readme} ({len(rows)} rows"
          + (f", baseline {args.baseline}" if args.baseline else "") + ")")


if __name__ == "__main__":
    main()
