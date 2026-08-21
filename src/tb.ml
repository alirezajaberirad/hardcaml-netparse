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

  (* The port bindings are annotated because [result] also has
     [valid]/[pass]/[channel] fields, and OCaml resolves a bare field access to
     the last-defined matching record type rather than to the port interface. *)
  let ports sim : Bits.t ref P.I.t * Bits.t ref P.O.t =
    (Cyclesim.inputs sim, Cyclesim.outputs sim)

  let sample (o : Bits.t ref P.O.t) : result option =
    if Bits.to_int !(o.valid) = 0
    then None
    else
      Some
        { valid = true
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

  let reset (i : Bits.t ref P.I.t) sim =
    i.clear := Bits.vdd;
    i.tvalid := Bits.gnd;
    i.tlast := Bits.gnd;
    Cyclesim.cycle sim;
    i.clear := Bits.gnd;
    Cyclesim.cycle sim

  (* Beats are driven with no gaps: an ingress parser has to sustain a
     continuous stream, because the wire does not stop. *)
  let drive_packet (i : Bits.t ref P.I.t) (o : Bits.t ref P.O.t) sim ~collect packet =
    List.iter
      (fun (tdata, tkeep, last) ->
         i.tvalid := Bits.vdd;
         i.tdata := tdata;
         i.tkeep := tkeep;
         i.tlast := (if last then Bits.vdd else Bits.gnd);
         Cyclesim.cycle sim;
         collect (sample o))
      (beats packet)

  let drain (i : Bits.t ref P.I.t) (o : Bits.t ref P.O.t) sim ~collect =
    i.tvalid := Bits.gnd;
    i.tlast := Bits.gnd;
    for _ = 1 to P.latency + 3 do
      Cyclesim.cycle sim;
      collect (sample o)
    done

  (** One packet, preceded by a reset, so a failure cannot cascade into the
      next case. *)
  let run sim (packet : Bytes.t) =
    let i, o = ports sim in
    let captured = ref no_result in
    let collect = function
      | Some r when not !captured.valid -> captured := r
      | _ -> ()
    in
    reset i sim;
    drive_packet i o sim ~collect packet;
    drain i o sim ~collect;
    !captured

  (** Several packets streamed back to back: one reset at the start, then no
      idle cycles and no clear between packets -- what a real MAC delivers.
      Returns one verdict per packet, in order.

      This is the case {!run} cannot reach. It exercises the framing handover:
      the beat counter reloading on tlast, hdr_done releasing in time for the
      next packet's first beat, and the accumulator's stale contents being
      shifted out by the incoming header rather than cleared. That last one is
      only correct because the accumulator is exactly [n_beats * w] bytes wide,
      so a full header displaces every bit of the previous packet. *)
  let run_stream sim (packets : Bytes.t list) =
    let i, o = ports sim in
    let acc = ref [] in
    let collect = function
      | Some r -> acc := r :: !acc
      | None -> ()
    in
    reset i sim;
    List.iter (drive_packet i o sim ~collect) packets;
    drain i o sim ~collect;
    List.rev !acc
end
