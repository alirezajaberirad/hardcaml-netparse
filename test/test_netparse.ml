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

let gapped_runners : (int * (gap:int -> Bytes.t -> Tb.result)) list =
  [ (4, (let s = W4.create () in fun ~gap p -> W4.run_gapped s ~gap p))
  ; (8, (let s = W8.create () in fun ~gap p -> W8.run_gapped s ~gap p))
  ; (16, (let s = W16.create () in fun ~gap p -> W16.run_gapped s ~gap p))
  ; (32, (let s = W32.create () in fun ~gap p -> W32.run_gapped s ~gap p))
  ; (64, (let s = W64.create () in fun ~gap p -> W64.run_gapped s ~gap p))
  ]

let stream_runners : (int * (Bytes.t list -> Tb.result list)) list =
  [ (4, (let s = W4.create () in fun ps -> W4.run_stream s ps))
  ; (8, (let s = W8.create () in fun ps -> W8.run_stream s ps))
  ; (16, (let s = W16.create () in fun ps -> W16.run_stream s ps))
  ; (32, (let s = W32.create () in fun ps -> W32.run_stream s ps))
  ; (64, (let s = W64.create () in fun ps -> W64.run_stream s ps))
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

(* Idle cycles between beats must not change the verdict. tvalid gates both the
   beat counter and the accumulator, so wait states should be invisible to the
   design; a parser that counted cycles rather than beats would pass every test
   above and fail this one. *)
let check_gapped ~name ~gap packet =
  let model = Ref_model.parse ~table packet in
  List.iter
    (fun (w, run) ->
       incr checks;
       let rtl = run ~gap packet in
       if not (Tb.agrees rtl model)
       then begin
         incr failures;
         Printf.printf
           "FAIL  W=%-2d  %s (gap=%d)\n      model: %s\n      diff:  %s\n"
           w
           name
           gap
           (Ref_model.to_string model)
           (Tb.diff rtl model)
       end)
    gapped_runners

(* Packets streamed back to back, no reset in between: the verdicts must come
   out in order, one per packet, with no dropped or duplicated pulses. A parser
   that only ever sees isolated packets can hide a framing bug that a real MAC
   would expose on the first busy microsecond. *)
let check_stream ~name packets =
  let models = List.map (Ref_model.parse ~table) packets in
  List.iter
    (fun (w, run) ->
       let rtls = run packets in
       incr checks;
       if List.length rtls <> List.length models
       then begin
         incr failures;
         Printf.printf
           "FAIL  W=%-2d  %s: %d verdicts emitted, %d packets sent\n"
           w
           name
           (List.length rtls)
           (List.length models)
       end
       else
         List.iteri
           (fun idx (rtl, model) ->
              incr checks;
              if not (Tb.agrees rtl model)
              then begin
                incr failures;
                Printf.printf
                  "FAIL  W=%-2d  %s [packet %d of %d]\n      model: %s\n      diff:  %s\n"
                  w
                  name
                  idx
                  (List.length models)
                  (Ref_model.to_string model)
                  (Tb.diff rtl model)
              end)
           (List.combine rtls models))
    stream_runners

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

  print_endline "-- wait states (idle cycles between beats) --";
  let gapped = ref 0 in
  List.iter
    (fun (name, packet) ->
       List.iter
         (fun gap ->
            incr gapped;
            check_gapped ~name ~gap packet)
         [ 1; 2; 5 ])
    (Packet_gen.corpus ~table);
  Printf.printf "   %d packet/gap combinations\n\n" !gapped;

  print_endline "-- back-to-back streams (no gaps, no reset between packets) --";
  let st2 = Random.State.make [| 0xbeef |] in
  let n_streams = 60 in
  let streamed = ref 0 in
  (* A directed stream first: a runt wedged between two good packets is the case
     where the framing state has to recover without the header ever completing. *)
  let good = Packet_gen.build { Packet_gen.default with dst_ip = 0xefc00001; dst_port = 15000 } in
  let runt = Bytes.sub good 0 20 in
  let bad = Packet_gen.build { Packet_gen.default with corrupt_checksum = true } in
  check_stream ~name:"good, runt, good" [ good; runt; good ];
  check_stream ~name:"runt, runt, good" [ runt; runt; good ];
  check_stream ~name:"good, bad-csum, good" [ good; bad; good ];
  check_stream ~name:"minimum-length x4"
    (List.init 4 (fun _ -> Packet_gen.build { Packet_gen.default with payload_len = 0 }));
  streamed := 4;
  for k = 1 to n_streams do
    let n = 2 + Random.State.int st2 6 in
    incr streamed;
    check_stream
      ~name:(Printf.sprintf "random stream #%d" k)
      (List.init n (fun _ -> Packet_gen.random_good st2 ~table))
  done;
  Printf.printf "   %d streams\n\n" !streamed;

  Printf.printf "%d checks, %d failures\n" !checks !failures;
  if !failures = 0
  then print_endline "PASS"
  else begin
    print_endline "FAILED";
    exit 1
  end
