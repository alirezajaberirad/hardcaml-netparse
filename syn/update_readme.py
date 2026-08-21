#!/usr/bin/env python3
"""Rewrite the results table in README.md from the Vivado CSV.

Kept as a script rather than pasted by hand so the published numbers cannot
drift from the ones synthesis actually produced.
"""

import csv
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
START = "<!-- RESULTS_TABLE_START -->"
END = "<!-- RESULTS_TABLE_END -->"


def required_mhz(datapath_bits, line_rate_gbps):
    """Clock a datapath of this width needs to sustain a given line rate."""
    return line_rate_gbps * 1e9 / datapath_bits / 1e6


def main():
    csv_path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                            else REPO / "syn" / "results" / "results.csv")
    readme = REPO / "README.md"

    rows = list(csv.DictReader(csv_path.read_text().splitlines()))
    if not rows:
        sys.exit(f"no rows in {csv_path}")

    part = rows[0]["part"]

    out = [
        f"Post-place-and-route, out-of-context, `{part}`.",
        "",
        "| Datapath | Header beats | LUT | FF | Fmax | 10 GbE | 25 GbE |",
        "| ---: | ---: | ---: | ---: | ---: | :---: | :---: |",
    ]
    for r in rows:
        bits = int(r["datapath_bits"])
        fmax = float(r["fmax_mhz"])
        need10 = required_mhz(bits, 10)
        need25 = required_mhz(bits, 25)
        out.append(
            "| {bits}-bit | {beats} | {lut} | {ff} | {fmax:.0f} MHz | {t10} | {t25} |".format(
                bits=bits,
                beats=r["beats"],
                lut=r["lut"],
                ff=r["ff"],
                fmax=fmax,
                t10="yes" if fmax >= need10 else "no",
                t25="yes" if fmax >= need25 else "no",
            )
        )
    out += [
        "",
        "Line rate needs `rate / datapath_width` — 156 MHz for 10 GbE at 64-bit, "
        "391 MHz for 25 GbE at 64-bit. Artix-7 is a low-cost 28 nm family; the "
        "same RTL on a UltraScale+ part would clock substantially higher.",
    ]

    text = readme.read_text(encoding="utf-8")
    before, _, rest = text.partition(START)
    _, _, after = rest.partition(END)
    readme.write_text(
        before + START + "\n" + "\n".join(out) + "\n" + END + after,
        encoding="utf-8",
    )
    print(f"updated {readme} from {csv_path} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
