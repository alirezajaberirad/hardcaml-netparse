(** Differential test: every packet goes through the pure-OCaml reference model
    and through the RTL at five datapath widths, and all six must agree.

    The load-bearing property is cross-width invariance. Datapath width is an
    implementation detail; if a packet's verdict changes when W changes, a field
    is being sliced out of the wrong place at some width. That single check
    catches essentially every straddling bug the accumulator design is meant to
    prevent. *)

open Netparse

let table = Filter_table.default

(* One simulator per width. Each [Tb.Make] instance has its own [Cyclesim]
   type, so each is wrapped in a closure that hides it; the list elements then
   share the common type [Bytes.t -> Tb.result]. *)
module W4 = Tb.Make (struct
    let datapath_bytes = 4
    let table = table
  end)

module W8 = Tb.Make (struct
    let datapath_bytes = 8
    let table = table
  end)

module W16 = Tb.Make (struct
    let datapath_bytes = 16
    let table = table
  end)

module W32 = Tb.Make (struct
    let datapath_bytes = 32
    let table = table
  end)

module W64 = Tb.Make (struct
    let datapath_bytes = 64
    let table = table
  end)

let runners : (int * (Bytes.t -> Tb.result)) list =
  [ (4, (let s = W4.create () in fun p -> W4.run s p))
  ; (8, (let s = W8.create () in fun p -> W8.run s p))
  ; (16, (let s = W16.create () in fun p -> W16.run s p))
  ; (32, (let s = W32.create () in fun p -> W32.run s p))
  ; (64, (let s = W64.create () in fun p -> W64.run s p))
  ]

let failures = ref 0
let checks = ref 0

let check ~name packet =
  let model = Ref_model.parse ~table packet in
  List.iter
    (fun (w, run) ->
       incr checks;
       let rtl = run packet in
       if not (Tb.agrees rtl model)
       then begin
         incr failures;
         Printf.printf
           "FAIL  W=%-2d  %s\n      model: %s\n      diff:  %s\n"
           w
           name
           (Ref_model.to_string model)
           (Tb.diff rtl model)
       end)
    runners

let () =
  print_endline "hardcaml-netparse differential test";
  print_endline "===================================";
  Printf.printf
    "widths: %s   table entries: %d\n\n"
    (String.concat ", " (List.map (fun (w, _) -> string_of_int (w * 8)) runners))
    (List.length table);

  print_endline "-- directed corpus --";
  List.iter (fun (name, packet) -> check ~name packet) (Packet_gen.corpus ~table);
  Printf.printf "   %d packets\n\n" (List.length (Packet_gen.corpus ~table));

  print_endline "-- randomised traffic --";
  let st = Random.State.make [| 0xc0ffee |] in
  let n_random = 2000 in
  for k = 1 to n_random do
    check ~name:(Printf.sprintf "random #%d" k) (Packet_gen.random_good st ~table)
  done;
  Printf.printf "   %d packets (seed 0xc0ffee, reproducible)\n\n" n_random;

  (* Payload lengths that make the header end exactly on, one before, and one
     after a beat boundary at each width. *)
  print_endline "-- beat-boundary sweep --";
  let sweep = ref 0 in
  for payload_len = 0 to 96 do
    incr sweep;
    check
      ~name:(Printf.sprintf "payload=%d" payload_len)
      (Packet_gen.build { Packet_gen.default with dst_ip = 0xefc00001; dst_port = 15000; payload_len })
  done;
  (* From 1, not 0: a zero-byte frame is unrepresentable on AXI4-Stream -- there
     is no beat on which to raise tlast -- so the RTL correctly sees no packet at
     all and emits nothing. Comparing that against the model's "short" verdict
     would be testing the harness, not the design. *)
  for len = 1 to Packet_defs.header_bytes do
    incr sweep;
    let full = Packet_gen.build Packet_gen.default in
    check ~name:(Printf.sprintf "truncated to %d" len) (Bytes.sub full 0 len)
  done;
  Printf.printf "   %d packets\n\n" !sweep;

  Printf.printf "%d checks, %d failures\n" !checks !failures;
  if !failures = 0
  then print_endline "PASS"
  else begin
    print_endline "FAILED";
    exit 1
  end
