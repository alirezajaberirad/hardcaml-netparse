(** Cycle-accurate test harness: pushes a packet through the RTL as an
    AXI4-Stream and returns the verdict in the same shape the reference model
    produces, so the two can be compared directly. *)

open Hardcaml

type result =
  { valid : bool
  ; pass : bool
  ; channel : int
  ; dst_ip : int
  ; dst_port : int
  ; short : bool
  ; vlan : bool
  ; not_ipv4 : bool
  ; bad_ihl : bool
  ; not_udp : bool
  ; fragment : bool
  ; bad_checksum : bool
  }

let no_result =
  { valid = false
  ; pass = false
  ; channel = 0
  ; dst_ip = 0
  ; dst_port = 0
  ; short = false
  ; vlan = false
  ; not_ipv4 = false
  ; bad_ihl = false
  ; not_udp = false
  ; fragment = false
  ; bad_checksum = false
  }

(** Compare an RTL result against the reference model.

    Short packets are compared loosely on purpose: when the header window never
    completed, the accumulator holds partial data and the field outputs are
    meaningless by construction. Asserting anything about them would be
    asserting on don't-cares. *)
let agrees (rtl : result) (model : Ref_model.verdict) =
  if model.short
  then rtl.valid && rtl.short && not rtl.pass
  else
    rtl.valid
    && (not rtl.short)
    && rtl.pass = model.pass
    && rtl.dst_ip = model.dst_ip
    && rtl.dst_port = model.dst_port
    && rtl.vlan = model.vlan
    && rtl.not_ipv4 = model.not_ipv4
    && rtl.bad_ihl = model.bad_ihl
    && rtl.not_udp = model.not_udp
    && rtl.fragment = model.fragment
    && rtl.bad_checksum = model.bad_checksum
    && ((not model.pass) || rtl.channel = model.channel)

let diff (rtl : result) (model : Ref_model.verdict) =
  let b name a b = if a <> b then [ Printf.sprintf "%s rtl=%b model=%b" name a b ] else [] in
  let i name a b = if a <> b then [ Printf.sprintf "%s rtl=%d model=%d" name a b ] else [] in
  String.concat ", "
    (List.concat
       [ (if rtl.valid then [] else [ "rtl produced no valid pulse" ])
       ; b "pass" rtl.pass model.pass
       ; b "short" rtl.short model.short
       ; i "dst_ip" rtl.dst_ip model.dst_ip
       ; i "dst_port" rtl.dst_port model.dst_port
       ; i "channel" rtl.channel model.channel
       ; b "vlan" rtl.vlan model.vlan
       ; b "not_ipv4" rtl.not_ipv4 model.not_ipv4
       ; b "bad_ihl" rtl.bad_ihl model.bad_ihl
       ; b "not_udp" rtl.not_udp model.not_udp
       ; b "fragment" rtl.fragment model.fragment
       ; b "bad_checksum" rtl.bad_checksum model.bad_checksum
       ])

module Make (Cfg : Parser_core.Config) = struct
  module P = Parser_core.Make (Cfg)
  module Sim = Cyclesim.With_interface (P.I) (P.O)

  let w = Cfg.datapath_bytes

  (** Split a packet into AXI4-Stream beats.

      [tdata] carries the first byte of the beat in the least significant lane,
      per AXI-Stream convention -- the RTL byte-swaps it back. [tkeep] marks the
      valid lanes, which only ever matters on the final beat. *)
  let beats (packet : Bytes.t) =
    let len = Bytes.length packet in
    let n = (len + w - 1) / w in
    List.init n (fun idx ->
      let off = idx * w in
      let n_valid = min w (len - off) in
      let byte k = if k < n_valid then Char.code (Bytes.get packet (off + k)) else 0 in
      (* concat_msb takes its head as the most significant element, so reverse
         the wire-order list to land byte 0 in the LSB lane. *)
      let tdata =
        Bits.concat_msb (List.rev (List.init w (fun k -> Bits.of_int ~width:8 (byte k))))
      in
      let tkeep =
        Bits.concat_msb
          (List.rev (List.init w (fun k -> if k < n_valid then Bits.vdd else Bits.gnd)))
      in
      (tdata, tkeep, idx = n - 1))

  let create () = Sim.create P.create

  (** Drive one packet through and return the verdict. Each call re-asserts
      clear first, so packets are independent and a failure in one cannot
      cascade into the next. *)
  let run sim (packet : Bytes.t) =
    let i = Cyclesim.inputs sim in
    let o = Cyclesim.outputs sim in
    let captured = ref no_result in
    let capture () =
      if Bits.to_int !(o.valid) = 1 && not !captured.valid
      then
        captured
        := { valid = true
           ; pass = Bits.to_int !(o.pass) = 1
           ; channel = Bits.to_int !(o.channel)
           ; dst_ip = Bits.to_int !(o.dst_ip)
           ; dst_port = Bits.to_int !(o.dst_port)
           ; short = Bits.to_int !(o.err_short) = 1
           ; vlan = Bits.to_int !(o.err_vlan) = 1
           ; not_ipv4 = Bits.to_int !(o.err_not_ipv4) = 1
           ; bad_ihl = Bits.to_int !(o.err_bad_ihl) = 1
           ; not_udp = Bits.to_int !(o.err_not_udp) = 1
           ; fragment = Bits.to_int !(o.err_fragment) = 1
           ; bad_checksum = Bits.to_int !(o.err_bad_checksum) = 1
           }
    in
    (* Reset. *)
    i.clear := Bits.vdd;
    i.tvalid := Bits.gnd;
    i.tlast := Bits.gnd;
    Cyclesim.cycle sim;
    i.clear := Bits.gnd;
    Cyclesim.cycle sim;
    (* Stream the packet with no gaps -- an ingress parser must sustain
       back-to-back beats. *)
    List.iter
      (fun (tdata, tkeep, last) ->
         i.tvalid := Bits.vdd;
         i.tdata := tdata;
         i.tkeep := tkeep;
         i.tlast := (if last then Bits.vdd else Bits.gnd);
         Cyclesim.cycle sim;
         capture ())
      (beats packet);
    i.tvalid := Bits.gnd;
    i.tlast := Bits.gnd;
    (* Drain the pipeline. *)
    for _ = 1 to P.latency + 3 do
      Cyclesim.cycle sim;
      capture ()
    done;
    !captured
end
