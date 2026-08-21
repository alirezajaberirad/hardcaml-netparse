(** Emits synthesizable Verilog for every datapath width in
    {!Filter_table.widths}.

    This executable is the whole "programming language technology improves
    hardware design" claim in miniature: five RTL variants, structurally
    different from each other, from one source with no duplicated logic. *)

open Hardcaml

let emit ~dir ~w =
  let module P =
    Parser_core.Make (struct
      let datapath_bytes = w
      let table = Filter_table.default
    end)
  in
  let module C = Circuit.With_interface (P.I) (P.O) in
  let name = Printf.sprintf "netparse_w%d" w in
  let circuit = C.create_exn ~name P.create in
  let file = Filename.concat dir (name ^ ".v") in
  Rtl.output ~output_mode:(To_file file) Verilog circuit;
  Printf.printf
    "  %-16s  %3d-bit datapath   %d header beats   %d-bit accumulator\n"
    (name ^ ".v")
    (w * 8)
    (Packet_defs.n_beats ~w)
    (Packet_defs.acc_bits ~w)

let () =
  let dir = if Array.length Sys.argv > 1 then Sys.argv.(1) else "rtl" in
  if not (Sys.file_exists dir) then Sys.mkdir dir 0o755;
  Printf.printf "generating Verilog into %s/\n" dir;
  List.iter (fun w -> emit ~dir ~w) Filter_table.widths
